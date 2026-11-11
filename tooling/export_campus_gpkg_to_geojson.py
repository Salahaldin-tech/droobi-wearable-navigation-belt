#!/usr/bin/env python3
"""Export QGIS campus GeoPackage layers to WGS84 GeoJSON."""
from __future__ import annotations
import argparse, json, math, sqlite3, struct
from pathlib import Path

def utm36_to_wgs84(x: float, y: float) -> list[float]:
    a,e,k=6378137.0,0.08181919084262149,0.9996
    e2=e*e; e1=(1-math.sqrt(1-e2))/(1+math.sqrt(1-e2))
    xx=x-500000; m=y/k
    mu=m/(a*(1-e2/4-3*e2*e2/64-5*e2**3/256))
    fp=(mu+(3*e1/2-27*e1**3/32)*math.sin(2*mu)
       +(21*e1**2/16-55*e1**4/32)*math.sin(4*mu)
       +(151*e1**3/96)*math.sin(6*mu)+(1097*e1**4/512)*math.sin(8*mu))
    ep2=e2/(1-e2); c=ep2*math.cos(fp)**2; t=math.tan(fp)**2
    n=a/math.sqrt(1-e2*math.sin(fp)**2)
    r=a*(1-e2)/(1-e2*math.sin(fp)**2)**1.5
    d=xx/(n*k)
    lat=fp-(n*math.tan(fp)/r)*(d*d/2-(5+3*t+10*c-4*c*c-9*ep2)*d**4/24+(61+90*t+298*c+45*t*t-252*ep2-3*c*c)*d**6/720)
    lon=math.radians(33)+(d-(1+2*t+c)*d**3/6+(5-2*c+28*t-3*c*c+8*ep2+24*t*t)*d**5/120)/math.cos(fp)
    return [math.degrees(lon),math.degrees(lat)]

def read_geometry(blob: bytes):
    if blob[:2]!=b"GP": raise ValueError("Invalid GeoPackage geometry")
    env=(blob[3]>>1)&7; dims={0:0,1:4,2:6,3:6,4:8}[env]
    p=8+dims*8; endian="<" if blob[p]==1 else ">"; p+=1
    typ=struct.unpack_from(endian+"I",blob,p)[0]&255; p+=4
    def u32():
        nonlocal p
        v=struct.unpack_from(endian+"I",blob,p)[0];p+=4;return v
    def xy():
        nonlocal p
        v=list(struct.unpack_from(endian+"dd",blob,p));p+=16;return v
    if typ==1: return {"type":"Point","coordinates":xy()}
    if typ==2: return {"type":"LineString","coordinates":[xy() for _ in range(u32())]}
    if typ==3:
        rings=[]
        for _ in range(u32()):
            rings.append([xy() for _ in range(u32())])
        return {"type":"Polygon","coordinates":rings}
    raise ValueError(f"Unsupported geometry type {typ}")

def transform(g):
    def walk(x):
        if isinstance(x,list) and len(x)==2 and all(isinstance(v,(int,float)) for v in x):
            return utm36_to_wgs84(float(x[0]),float(x[1]))
        return [walk(v) for v in x]
    return {"type":g["type"],"coordinates":walk(g["coordinates"])}

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--input",required=True,type=Path)
    p.add_argument("--output-dir",required=True,type=Path)
    a=p.parse_args(); a.output_dir.mkdir(parents=True,exist_ok=True)
    layers={"nodes":("geom","nodes_v3.geojson"),"edges":("geometry","edges_v3.geojson"),"buildings":("geometry","buildings_v3.geojson"),"barriers":("geometry","barriers_v3.geojson")}
    with sqlite3.connect(a.input) as db:
        row=db.execute("SELECT srs_id FROM gpkg_geometry_columns WHERE table_name='nodes'").fetchone()
        if row is None or row[0]!=32636: raise SystemExit(f"Expected EPSG:32636; found {row!r}")
        for table,(geom_col,filename) in layers.items():
            cursor=db.execute(f'SELECT * FROM "{table}" ORDER BY fid')
            cols=[x[0] for x in cursor.description]; features=[]
            for row in cursor:
                props=dict(zip(cols,row)); geom=transform(read_geometry(props.pop(geom_col)))
                features.append({"type":"Feature","id":props.get("fid"),"properties":props,"geometry":geom})
            target=a.output_dir/filename
            target.write_text(json.dumps({"type":"FeatureCollection","features":features},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
            print(f"{table}: {len(features)}")

if __name__=="__main__": main()

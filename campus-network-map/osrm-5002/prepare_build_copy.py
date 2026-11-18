"""Build copy for the port-5002 test: drop JOSM-deleted elements, connect way -1024,
renumber negative ids. Never touches the input file."""
import sys, math, csv
import xml.etree.ElementTree as ET
src, dst, idmap = sys.argv[1:4]
tree = ET.parse(src); root = tree.getroot()
K = math.cos(math.radians(32.408))
def xy(p): return (p[1]*111320*K, p[0]*111320)
def ll(q): return (q[1]/111320, q[0]/(111320*K))
nodes = {n.get('id'): n for n in root.findall('node')}
ways = {w.get('id'): w for w in root.findall('way')}
P = lambda k: (float(nodes[k].get('lat')), float(nodes[k].get('lon')))
# 1) drop action=delete
dropped = [(e.tag, e.get('id')) for e in list(root) if e.get('action') == 'delete']
refs = {nd.get('ref') for w in root.findall('way') if w.get('action') != 'delete' for nd in w.findall('nd')}
assert not any(i in refs for t, i in dropped if t == 'node'), 'deleted node still referenced'
for e in list(root):
    if e.get('action') == 'delete': root.remove(e)
nodes = {n.get('id'): n for n in root.findall('node')}; ways = {w.get('id'): w for w in root.findall('way')}
print('dropped', len(dropped), dropped)
nxt = [-900001]
def new_node(lat, lon):
    i = str(nxt[0]); nxt[0] -= 1
    e = ET.Element('node', id=i, lat=f'{lat:.11f}', lon=f'{lon:.11f}')
    root.insert(list(root).index(next(iter(nodes.values()))), e); nodes[i] = e; return i
def insert_between(wid, a, b, nid):
    w = ways[wid]; nds = w.findall('nd'); r = [x.get('ref') for x in nds]
    for k in range(len(r)-1):
        if {r[k], r[k+1]} == {a, b}:
            w.insert(list(w).index(nds[k+1]), ET.Element('nd', ref=nid)); return
    raise SystemExit(f'segment {a}-{b} not in {wid}')
def cross(a, b, s, t):
    (x1,y1),(x2,y2),(x3,y3),(x4,y4) = map(xy, (P(a),P(b),P(s),P(t)))
    den = (x1-x2)*(y3-y4)-(y1-y2)*(x3-x4); tt = ((x1-x3)*(y3-y4)-(y1-y3)*(x3-x4))/den
    return ll((x1+tt*(x2-x1), y1+tt*(y2-y1)))
# 2) crossing with south link 1573510575
c1 = new_node(*cross('-26511', '14332475782', '14332475799', '14332475798'))
insert_between('-1024', '-26511', '14332475782', c1); insert_between('1573510575', '14332475799', '14332475798', c1)
# 3) crossing with parking aisle 1573528467
c2 = new_node(*cross('-26507', '-26511', '14332671927', '14332671928'))
insert_between('-1024', '-26507', '-26511', c2); insert_between('1573528467', '14332671927', '14332671928', c2)
# 4) endpoint -26507 -> perpendicular foot on the nearest aisle segment
aisle = [x.get('ref') for x in ways['1573528467'].findall('nd')]
px, py = xy(P('-26507')); best = None
for a, b in zip(aisle, aisle[1:]):
    (x1,y1),(x2,y2) = xy(P(a)), xy(P(b)); dx, dy = x2-x1, y2-y1
    t = max(0, min(1, ((px-x1)*dx+(py-y1)*dy)/(dx*dx+dy*dy))); q = (x1+t*dx, y1+t*dy)
    dd = math.dist((px,py), q)
    if best is None or dd < best[0]: best = (dd, a, b, q)
dd, a, b, q = best
c3 = new_node(*ll(q)); insert_between('1573528467', a, b, c3)
w = ways['-1024']; w.insert(list(w).index(w.find('nd')), ET.Element('nd', ref=c3))
for name, i in (('C1 x 1573510575', c1), ('C2 x 1573528467', c2), ('C3 end link', c3)):
    print(name, i, P(i))
print(f'endpoint -26507 -> {c3}: {dd:.2f} m, inserted into 1573528467 between {a} and {b}')
print('-1024 now', [x.get('ref') for x in ways['-1024'].findall('nd')])
print('1573510575 now', [x.get('ref') for x in ways['1573510575'].findall('nd')])
print('1573528467 head', [x.get('ref') for x in ways['1573528467'].findall('nd')][:6])
# 5) renumber negative ids to positive, strip JOSM action attrs
mx = max(int(e.get('id')) for e in root if e.get('id') and int(e.get('id')) > 0)
neg = sorted({e.get('id') for e in root if e.get('id', '0').startswith('-')}, key=lambda s: (root.find(f"*[@id='{s}']").tag != 'node', -int(s)))
m = {old: str(mx + 1 + k) for k, old in enumerate(neg)}
for e in root.iter():
    for attr in ('id', 'ref'):
        if e.get(attr) in m: e.set(attr, m[e.get(attr)])
    if 'action' in e.attrib: del e.attrib['action']
with open(idmap, 'w', newline='') as f:
    cw = csv.writer(f); cw.writerow(['josm_id', 'build_id'])
    for k, v in m.items(): cw.writerow([k, v])
print('renumbered', len(m), 'ids from', mx + 1)
tree.write(dst, encoding='UTF-8', xml_declaration=True)

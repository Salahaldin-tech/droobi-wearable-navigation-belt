/*
  AAUP Jenin campus — preliminary OSM source extraction
  AOI: provisional WGS84 envelope derived from Drawing1.dxf extents
  South, West, North, East:
  32.4034, 35.3401, 32.4116, 35.3487

  IMPORTANT:
  - This is a source-discovery extract, not a final campus clip.
  - Preserve the raw response and record extraction timestamp + endpoint.
  - OSM data is ODbL; retain attribution and assess share-alike obligations.
  - Do not treat every highway feature as a pedestrian-accessible path.
*/

[out:json][timeout:120];

(
  nwr["highway"](32.4034,35.3401,32.4116,35.3487);
  nwr["building"](32.4034,35.3401,32.4116,35.3487);
  nwr["entrance"](32.4034,35.3401,32.4116,35.3487);
  nwr["barrier"](32.4034,35.3401,32.4116,35.3487);
  nwr["access"](32.4034,35.3401,32.4116,35.3487);
  nwr["indoor"](32.4034,35.3401,32.4116,35.3487);
  nwr["amenity"](32.4034,35.3401,32.4116,35.3487);
  nwr["natural"](32.4034,35.3401,32.4116,35.3487);
  nwr["landuse"](32.4034,35.3401,32.4116,35.3487);
  nwr["leisure"](32.4034,35.3401,32.4116,35.3487);
  nwr["stairs"](32.4034,35.3401,32.4116,35.3487);
);

out geom;

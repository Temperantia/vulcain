data = require('./data.json');
fs = require('fs');

features = {};
for (feature of data['features']) {
  features[feature['properties']['COORD_100']] = feature['geometry']['coordinates'][0];
  //features[feature['properties']['NOM']] = feature['geometry']['coordinates'][0];
}
fs.writeFileSync('./dfci_level_1.json', JSON.stringify(features));
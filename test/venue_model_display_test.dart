import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/hospitality/venue_model.dart';

void main() {
  group('VenueModel display labels', () {
    test('humanizes backend primary category values', () {
      const venue = VenueModel(
        id: 'venue_1',
        name: 'Zizka',
        countryCode: CountryCode.mt,
        venueType: VenueType.bar,
        currencyCode: 'EUR',
        city: 'Valletta',
        primaryCategory: 'sports_bar',
      );

      expect(venue.primaryCategoryLabel, 'Sports bar');
      expect(venue.discoverySubtitle, 'Valletta · Bar · Sports bar');
    });

    test('uses venue type when city and category are absent', () {
      const venue = VenueModel(
        id: 'venue_2',
        name: 'Remote Venue',
        countryCode: CountryCode.rw,
        venueType: VenueType.event,
        currencyCode: 'RWF',
      );

      expect(venue.primaryCategoryLabel, isNull);
      expect(venue.discoverySubtitle, 'Event');
    });
  });
}

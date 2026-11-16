import 'dart:async';

import 'package:streamtunes/domain/models/donation.dart';

abstract class DonationsRepository {
  Stream<Donation> get donationCreatedStream;
  Future<List<Donation>> getDonationsByBand(String bandId);
  Future<Donation> createDonation(Donation donation);
  void dispose();
}

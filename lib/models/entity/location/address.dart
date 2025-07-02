class Address {
  String? street;
  String? ward;
  String? district;
  String? province;
  String? city;

  Address({this.street, this.ward, this.district, this.province, this.city});

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'],
      ward: json['ward'],
      district: json['district'],
      province: json['province'],
      city: json['city'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'ward': ward,
      'district': district,
      'province': province,
      'city': city,
    };
  }

  bool get isComplete {
    return street != null &&
        street!.isNotEmpty &&
        district != null &&
        district!.isNotEmpty &&
        province != null &&
        province!.isNotEmpty;
  }

  @override
  String toString() {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (ward != null && ward!.isNotEmpty) parts.add(ward!);
    if (district != null && district!.isNotEmpty) parts.add(district!);
    if (province != null && province!.isNotEmpty) parts.add(province!);
    if (city != null && city!.isNotEmpty && city != province) parts.add(city!);

    return parts.join(', ');
  }
}

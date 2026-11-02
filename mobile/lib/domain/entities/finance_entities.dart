import 'package:equatable/equatable.dart';

/// Tổng hợp thu nhập của Barber (CHỈ cộng hoa hồng 10% khi Booking COMPLETED).
class BarberIncomeSummary extends Equatable {
  final String barberId;
  final String barberName;
  final int baseSalary;
  final int completedCustomerCount;
  final int completedServiceRevenue;
  final int commissionAmount; // 10% của completedServiceRevenue
  final int totalIncome; // baseSalary + commissionAmount
  final String expectedPaydayText;

  const BarberIncomeSummary({
    required this.barberId,
    required this.barberName,
    required this.baseSalary,
    required this.completedCustomerCount,
    required this.completedServiceRevenue,
    required this.commissionAmount,
    required this.totalIncome,
    required this.expectedPaydayText,
  });

  @override
  List<Object?> get props => [
        barberId,
        baseSalary,
        completedCustomerCount,
        completedServiceRevenue,
        commissionAmount,
        totalIncome,
      ];
}

class BarberPayrollItem extends Equatable {
  final String barberId;
  final String barberName;
  final int baseSalary;
  final int completedCustomerCount;
  final int generatedRevenue;
  final int commissionAmount;
  final int totalPayout;

  const BarberPayrollItem({
    required this.barberId,
    required this.barberName,
    required this.baseSalary,
    required this.completedCustomerCount,
    required this.generatedRevenue,
    required this.commissionAmount,
    required this.totalPayout,
  });

  @override
  List<Object?> get props => [
        barberId,
        baseSalary,
        completedCustomerCount,
        generatedRevenue,
        commissionAmount,
        totalPayout,
      ];
}

/// Doanh thu và bảng lương của Quán (CHỈ cộng doanh thu từ các Booking COMPLETED).
class ShopRevenueSummary extends Equatable {
  final String shopId;
  final int completedBookingCount;
  final int totalShopRevenue;
  final int totalBarberPayout;
  final int netProfit;
  final List<BarberPayrollItem> barberPayrolls;

  const ShopRevenueSummary({
    required this.shopId,
    required this.completedBookingCount,
    required this.totalShopRevenue,
    required this.totalBarberPayout,
    required this.netProfit,
    required this.barberPayrolls,
  });

  @override
  List<Object?> get props => [
        shopId,
        completedBookingCount,
        totalShopRevenue,
        totalBarberPayout,
        netProfit,
        barberPayrolls,
      ];
}

class MonthlyBookingHeatDay extends Equatable {
  final DateTime date;
  final int totalBookings;
  final int completedBookings;

  const MonthlyBookingHeatDay({
    required this.date,
    required this.totalBookings,
    required this.completedBookings,
  });

  @override
  List<Object?> get props => [date, totalBookings, completedBookings];
}


double riderNetPay({
  required num baseSalary,
  required int deliveries,
  required num perDeliveryBonus,
  required num fuelAllowance,
  required num advance,
}) => (baseSalary + deliveries * perDeliveryBonus + fuelAllowance - advance)
    .toDouble();

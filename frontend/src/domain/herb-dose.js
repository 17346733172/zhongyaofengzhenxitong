const numbers = new Intl.NumberFormat("zh-CN", { useGrouping: false, maximumFractionDigits: 6 });
const countUnits = { piece: "片", item: "枚" };

export function isCountHerb(herb) {
  return herb.unit === "piece" || herb.unit === "item";
}

export function herbUnit(herb) {
  return isCountHerb(herb) ? countUnits[herb.unit] : "g";
}

export function herbDose(herb, doses = 1) {
  const amount = isCountHerb(herb) ? herb.quantity_per_dose : herb.grams_per_dose;
  if (amount == null || !Number.isFinite(amount) || amount <= 0) return "待补充";
  return `${numbers.format(amount * doses)} ${herbUnit(herb)}`;
}

export function herbWeight(herb) {
  return herb.grams_per_dose == null ? "待称重" : `${numbers.format(herb.grams_per_dose)} g/剂`;
}

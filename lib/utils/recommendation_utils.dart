String getDroughtRecommendation(String droughtLevel) {
  switch (droughtLevel) {
    case "[0]":
      return "No hay sequía. Mantén las prácticas normales de riego.";
    case "[1]":
      return "Sequía leve. Incrementa la monitorización de la humedad del suelo.";
    case "[2]":
      return "Sequía moderada. Optimiza el riego y reduce el uso innecesario de agua.";
    case "[3]":
      return "Sequía severa. Prioriza los cultivos más importantes.";
    case "[4]":
      return "Sequía extrema. Implementa estrategias de conservación de agua.";
    case "[5]":
      return "Sequía severa. Considera medidas de emergencia para proteger cultivos.";
    default:
      return "Nivel de sequía desconocido.";
  }
}

String getFloodRecommendation(String floodRisk) {
  if (floodRisk == "1") {
    return "Alto riesgo de inundación. Asegúrate de proteger los cultivos y verifica sistemas de drenaje.";
  } else {
    return "No hay riesgo de inundación. Mantén prácticas regulares.";
  }
}
String getFireRecommendation(String fireRisk) {
  if (fireRisk == "1") {
    return "Alto riesgo de incendio. Asegúrate de mantener despejadas las áreas circundantes y evita actividades que puedan generar chispas.";
  } else {
    return "Bajo riesgo de incendio. Continúa monitoreando las condiciones ambientales.";
  }
}

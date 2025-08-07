package handlers

import (
	"strconv"
)

func (h *WeatherHandler) cacheKey(rq WeatherRQ) string {
	lat := roundTo(rq.Lat, 2)
	lon := roundTo(rq.Lon, 2)
	b := make([]byte, 0, 64)
	b = append(b, "weather:v1:"...)
	b = append(b, strconv.FormatFloat(lat, 'f', 2, 64)...)
	b = append(b, ':')
	b = append(b, strconv.FormatFloat(lon, 'f', 2, 64)...)
	b = append(b, ':')
	b = append(b, rq.Units...)
	b = append(b, ':')
	b = append(b, strconv.Itoa(rq.Days)...)
	b = append(b, ':')
	b = append(b, strconv.Itoa(rq.Hours)...)
	return string(b)
}

func roundTo(v float64, decimals int) float64 {
	pow := 1.0
	for i := 0; i < decimals; i++ {
		pow *= 10
	}
	iv := int64(v*pow + 0.5)
	return float64(iv) / pow
}

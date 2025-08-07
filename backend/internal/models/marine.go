package models

type MarineUnits struct {
	WaveHeight     string `json:"wave_height"`
	WavePeriod     string `json:"wave_period"`
	WaveDirection  string `json:"wave_direction"`
	SwellHeight    string `json:"swell_height"`
	SwellPeriod    string `json:"swell_period"`
	SwellDirection string `json:"swell_direction"`
}

type MarineHour struct {
	Time           string  `json:"time"`
	WaveHeight     float64 `json:"wave_height"`
	WavePeriod     float64 `json:"wave_period"`
	WaveDirection  float64 `json:"wave_direction"`
	SwellHeight    float64 `json:"swell_height"`
	SwellPeriod    float64 `json:"swell_period"`
	SwellDirection float64 `json:"swell_direction"`
}

type MarineNormalized struct {
	Latitude  float64      `json:"latitude"`
	Longitude float64      `json:"longitude"`
	Timezone  string       `json:"timezone"`
	Units     MarineUnits  `json:"units"`
	Hourly    []MarineHour `json:"hourly"`
}

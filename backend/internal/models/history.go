package models

type HistoryUnits struct {
	TempMax       string `json:"temp_max"`
	TempMin       string `json:"temp_min"`
	Precipitation string `json:"precipitation"`
}

type HistoryDay struct {
	Date             string  `json:"date"`
	TempMax          float64 `json:"temp_max"`
	TempMin          float64 `json:"temp_min"`
	PrecipitationSum float64 `json:"precipitation_sum"`
}

type HistoryNormalized struct {
	Latitude  float64      `json:"latitude"`
	Longitude float64      `json:"longitude"`
	Timezone  string       `json:"timezone"`
	Units     HistoryUnits `json:"units"`
	Daily     []HistoryDay `json:"daily"`
}





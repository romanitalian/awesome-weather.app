package models

type WeatherUnits struct {
	Temperature   string `json:"temperature"`
	WindSpeed     string `json:"wind_speed"`
	WindGust      string `json:"wind_gust"`
	WindDirection string `json:"wind_direction"`
	Precipitation string `json:"precipitation"`
	Pressure      string `json:"pressure"`
	CloudCover    string `json:"cloud_cover"`
}

type Current struct {
	Time          string  `json:"time"`
	Temperature   float64 `json:"temperature"`
	WindSpeed     float64 `json:"wind_speed"`
	WindDirection float64 `json:"wind_direction"`
}

type Hour struct {
	Time          string  `json:"time"`
	Temperature   float64 `json:"temperature"`
	WindSpeed     float64 `json:"wind_speed"`
	WindGust      float64 `json:"wind_gust"`
	WindDirection float64 `json:"wind_direction"`
	Precipitation float64 `json:"precipitation"`
	Pressure      float64 `json:"pressure"`
	CloudCover    float64 `json:"cloud_cover"`
}

type Day struct {
	Date                  string  `json:"date"`
	TempMax               float64 `json:"temp_max"`
	TempMin               float64 `json:"temp_min"`
	PrecipitationSum      float64 `json:"precipitation_sum"`
	WindSpeedMax          float64 `json:"wind_speed_max"`
	WindGustsMax          float64 `json:"wind_gusts_max"`
	WindDirectionDominant float64 `json:"wind_direction_dominant"`
	Sunrise               string  `json:"sunrise"`
	Sunset                string  `json:"sunset"`
}

type WeatherNormalized struct {
	Latitude  float64      `json:"latitude"`
	Longitude float64      `json:"longitude"`
	Timezone  string       `json:"timezone"`
	Units     WeatherUnits `json:"units"`
	Current   Current      `json:"current"`
	Hourly    []Hour       `json:"hourly"`
	Daily     []Day        `json:"daily"`
}

package models

type TideUnits struct {
	Height string `json:"height"`
}

type TideExtremum struct {
	Time   string  `json:"time"`
	Height float64 `json:"height"`
	Type   string  `json:"type"` // High/Low
}

type TidesNormalized struct {
	Latitude  float64        `json:"latitude"`
	Longitude float64        `json:"longitude"`
	Units     TideUnits      `json:"units"`
	Extremes  []TideExtremum `json:"extremes"`
}

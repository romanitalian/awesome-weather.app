package models

import (
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

// WeatherUnits defines measurement units for weather data
type WeatherUnits struct {
	Temperature   string `json:"temperature" validate:"required,oneof=celsius fahrenheit"`
	WindSpeed     string `json:"wind_speed" validate:"required,oneof=kmh mph ms"`
	WindGust      string `json:"wind_gust" validate:"required,oneof=kmh mph ms"`
	WindDirection string `json:"wind_direction" validate:"required,eq=degrees"`
	Precipitation string `json:"precipitation" validate:"required,oneof=mm in"`
	Pressure      string `json:"pressure" validate:"required,oneof=hPa inHg"`
	CloudCover    string `json:"cloud_cover" validate:"required,eq=percent"`
}

// Current weather conditions
type Current struct {
	Time          time.Time `json:"time" validate:"required"`
	Temperature   float64   `json:"temperature" validate:"required"`
	WindSpeed     float64   `json:"wind_speed" validate:"required,min=0"`
	WindDirection float64   `json:"wind_direction" validate:"required,min=0,max=360"`
	Humidity      float64   `json:"humidity,omitempty" validate:"omitempty,min=0,max=100"`
	Pressure      float64   `json:"pressure,omitempty" validate:"omitempty,min=800,max=1200"`
	CloudCover    float64   `json:"cloud_cover,omitempty" validate:"omitempty,min=0,max=100"`
	UVIndex       float64   `json:"uv_index,omitempty" validate:"omitempty,min=0,max=15"`
}

// Hour represents hourly forecast
type Hour struct {
	Time          time.Time `json:"time" validate:"required"`
	Temperature   float64   `json:"temperature" validate:"required"`
	WindSpeed     float64   `json:"wind_speed" validate:"required,min=0"`
	WindGust      float64   `json:"wind_gust,omitempty" validate:"omitempty,min=0"`
	WindDirection float64   `json:"wind_direction" validate:"required,min=0,max=360"`
	Precipitation float64   `json:"precipitation" validate:"required,min=0"`
	Pressure      float64   `json:"pressure,omitempty" validate:"omitempty,min=800,max=1200"`
	CloudCover    float64   `json:"cloud_cover,omitempty" validate:"omitempty,min=0,max=100"`
	Humidity      float64   `json:"humidity,omitempty" validate:"omitempty,min=0,max=100"`
	UVIndex       float64   `json:"uv_index,omitempty" validate:"omitempty,min=0,max=15"`
}

// Day represents daily forecast
type Day struct {
	Date                  time.Time `json:"date" validate:"required"`
	TempMax               float64   `json:"temp_max" validate:"required"`
	TempMin               float64   `json:"temp_min" validate:"required"`
	PrecipitationSum      float64   `json:"precipitation_sum" validate:"required,min=0"`
	WindSpeedMax          float64   `json:"wind_speed_max" validate:"required,min=0"`
	WindGustsMax          float64   `json:"wind_gusts_max,omitempty" validate:"omitempty,min=0"`
	WindDirectionDominant float64   `json:"wind_direction_dominant" validate:"required,min=0,max=360"`
	Sunrise               time.Time `json:"sunrise" validate:"required"`
	Sunset                time.Time `json:"sunset" validate:"required"`
	UVIndexMax            float64   `json:"uv_index_max,omitempty" validate:"omitempty,min=0,max=15"`
}

// WeatherNormalized represents normalized weather data
type WeatherNormalized struct {
	Latitude  float64      `json:"latitude" validate:"required,min=-90,max=90"`
	Longitude float64      `json:"longitude" validate:"required,min=-180,max=180"`
	Timezone  string       `json:"timezone" validate:"required"`
	Units     WeatherUnits `json:"units" validate:"required"`
	Current   Current      `json:"current" validate:"required"`
	Hourly    []Hour       `json:"hourly" validate:"required,min=1,max=168"` // max 7 days
	Daily     []Day        `json:"daily" validate:"required,min=1,max=16"`   // max 16 days
}

// Validate checks if WeatherNormalized is valid
func (w *WeatherNormalized) Validate() error {
	if w.Latitude < -90 || w.Latitude > 90 {
		return errors.New("latitude must be between -90 and 90")
	}
	if w.Longitude < -180 || w.Longitude > 180 {
		return errors.New("longitude must be between -180 and 180")
	}
	if w.Timezone == "" {
		return errors.New("timezone is required")
	}
	if len(w.Hourly) == 0 {
		return errors.New("hourly forecast is required")
	}
	if len(w.Daily) == 0 {
		return errors.New("daily forecast is required")
	}
	if len(w.Hourly) > 168 {
		return errors.New("hourly forecast cannot exceed 168 hours (7 days)")
	}
	if len(w.Daily) > 16 {
		return errors.New("daily forecast cannot exceed 16 days")
	}

	// Validate current
	if w.Current.Time.IsZero() {
		return errors.New("current time is required")
	}
	if w.Current.WindSpeed < 0 {
		return errors.New("wind speed cannot be negative")
	}
	if w.Current.WindDirection < 0 || w.Current.WindDirection > 360 {
		return errors.New("wind direction must be between 0 and 360 degrees")
	}

	// Validate hourly data
	for i, hour := range w.Hourly {
		if hour.Time.IsZero() {
			return fmt.Errorf("hourly[%d]: time is required", i)
		}
		if hour.WindSpeed < 0 {
			return fmt.Errorf("hourly[%d]: wind speed cannot be negative", i)
		}
		if hour.WindDirection < 0 || hour.WindDirection > 360 {
			return fmt.Errorf("hourly[%d]: wind direction must be between 0 and 360 degrees", i)
		}
		if hour.Precipitation < 0 {
			return fmt.Errorf("hourly[%d]: precipitation cannot be negative", i)
		}
	}

	// Validate daily data
	for i, day := range w.Daily {
		if day.Date.IsZero() {
			return fmt.Errorf("daily[%d]: date is required", i)
		}
		if day.TempMax < day.TempMin {
			return fmt.Errorf("daily[%d]: temp_max cannot be less than temp_min", i)
		}
		if day.PrecipitationSum < 0 {
			return fmt.Errorf("daily[%d]: precipitation_sum cannot be negative", i)
		}
		if day.WindSpeedMax < 0 {
			return fmt.Errorf("daily[%d]: wind_speed_max cannot be negative", i)
		}
		if day.WindDirectionDominant < 0 || day.WindDirectionDominant > 360 {
			return fmt.Errorf("daily[%d]: wind_direction_dominant must be between 0 and 360 degrees", i)
		}
		if day.Sunrise.IsZero() {
			return fmt.Errorf("daily[%d]: sunrise is required", i)
		}
		if day.Sunset.IsZero() {
			return fmt.Errorf("daily[%d]: sunset is required", i)
		}
	}

	return nil
}

// MarshalJSON ensures proper JSON marshaling with validation
func (w *WeatherNormalized) MarshalJSON() ([]byte, error) {
	if err := w.Validate(); err != nil {
		return nil, fmt.Errorf("validation failed: %w", err)
	}

	// Create a type alias to avoid infinite recursion
	type WeatherNormalizedAlias WeatherNormalized
	return json.Marshal((*WeatherNormalizedAlias)(w))
}

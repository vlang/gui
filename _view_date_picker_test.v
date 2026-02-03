module gui

import time

fn test_date_helpers() {
	d := date(1, 1, 2023)
	assert d.year == 2023
	assert d.month == 1
	assert d.day == 1

	d2 := date(32, 1, 2023)
	// The `date` helper in view_date_picker uses time.new which normalizes?
	// Actually `view_date_picker.v`: return time.new(...)
	// V's `time.new` usually normalizes.
	// But let's check `is_same_day`
	assert is_same_day(d, time.new(day: 1, month: 1, year: 2023))
}

fn test_update_selections_single() {
	cfg := DatePickerCfg{
		id:              'test'
		dates:           []
		select_multiple: false
	}
	state := DatePickerState{
		view_month: 10
		view_year:  2023
	}

	// Select 5th
	res := cfg.update_selections(5, state)
	assert res.len == 1
	assert res[0].day == 5
	assert res[0].month == 10
	assert res[0].year == 2023

	// Select another day
	res2 := cfg.update_selections(10, state)
	assert res2.len == 1
	assert res2[0].day == 10
}

fn test_update_selections_multiple() {
	d1 := time.new(day: 1, month: 1, year: 2023)
	cfg := DatePickerCfg{
		id:              'test'
		dates:           [d1]
		select_multiple: true
	}
	state := DatePickerState{
		view_month: 1
		view_year:  2023
	}

	// Select 2nd. Should add.
	res := cfg.update_selections(2, state)
	assert res.len == 2
	assert is_same_day(res[0], d1)
	assert res[1].day == 2

	// Select 1st again. Should remove.
	res2 := cfg.update_selections(1, state)
	assert res2.len == 0

	// Should only have d1 removed. But wait, `update_selections` takes `state` which might be different?
	// No, `update_selections` reads `cfg.dates` as the base.
	// So `cfg.dates` still has `d1`.
	// If I click 1st (which is d1), it should return remaining list.
	// `dates` helper map it.
	// `selections << dates(cfg.dates)` -> [d1]
	// Remove d1. Result: empty.
	assert res2.len == 0
}

fn test_disabled_weekdays() {
	// Mondays allowed only
	cfg := DatePickerCfg{
		id:               'test'
		dates:            []
		allowed_weekdays: [.monday]
	}
	state := DatePickerState{
		view_month: 1
		view_year:  2023
	}

	// Jan 1 2023 is a Sunday. Should be disabled.
	d_sun := date(1, 1, 2023)
	assert cfg.disabled(d_sun, state) == true

	// Jan 2 2023 is a Monday. Should be enabled.
	d_mon := date(2, 1, 2023)
	assert cfg.disabled(d_mon, state) == false
}

fn test_disabled_months() {
	// Only January allowed
	cfg := DatePickerCfg{
		id:             'test'
		dates:          []
		allowed_months: [.january]
	}
	// View state here is less relevant for the specific date check inside disabled,
	// but `disabled` implementation currently reads `state.view_month` for the month check logic?
	// Let's check logic:
	// `month := DatePickerMonths.from(u16(state.view_month))`
	// So it checks if the *entire view month* is allowed, not the specific day's month?
	// Wait, if `state.view_month` is the one being checked, then it disables the whole view?
	// The implementation of disabled() says:
	// if cfg.allowed_months.len > 0 {
	//    month := DatePickerMonths.from(state.view_month) ...
	//    if month !in cfg.allowed_months { return true }
	// }
	// So YES, it disables based on the CURRENT VIEW month.

	state_jan := DatePickerState{
		view_month: 1
		view_year:  2023
	}
	// Pass any date, logic depends on state.view_month
	d := date(1, 1, 2023)
	assert cfg.disabled(d, state_jan) == false

	state_feb := DatePickerState{
		view_month: 2
		view_year:  2023
	}
	assert cfg.disabled(d, state_feb) == true
}

fn test_disabled_years() {
	cfg := DatePickerCfg{
		id:            'test'
		dates:         []
		allowed_years: [2023]
	}

	// Logic checks state.view_year
	state_2023 := DatePickerState{
		view_month: 1
		view_year:  2023
	}
	d := date(1, 1, 2023)
	assert cfg.disabled(d, state_2023) == false

	state_2024 := DatePickerState{
		view_month: 1
		view_year:  2024
	}
	assert cfg.disabled(d, state_2024) == true
}

fn test_disabled_specific_dates() {
	target := date(15, 1, 2023)
	cfg := DatePickerCfg{
		id:            'test'
		dates:         []
		allowed_dates: [target]
	}
	state := DatePickerState{
		view_month: 1
		view_year:  2023
	}

	// 15th allowed
	assert cfg.disabled(target, state) == false

	// 16th disabled
	other := date(16, 1, 2023)
	assert cfg.disabled(other, state) == true
}

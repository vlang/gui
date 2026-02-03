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

local M = {}

function M.generate_number_range(start, stop, step)
	local numbers = {}
	for num = start, stop, step do
		table.insert(numbers, num)
	end
	return numbers
end

return M

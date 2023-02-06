local M = {}

function M.generate_number_range(start, stop, step)
	local numbers = {}
	for num = start, stop, step or 1 do
		table.insert(numbers, num)
	end
	return numbers
end

function M.reverse_array(tbl)
	local rev = {}
	for i = #tbl, 1, -1 do
		rev[#rev + 1] = tbl[i]
	end
	return rev
end

return M

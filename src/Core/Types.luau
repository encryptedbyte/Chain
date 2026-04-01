--!strict
-- Basic types
export type StringQuery = string
export type BaseQuery<VAL, RET> = (item: VAL) -> RET
export type KeyValueBaseQuery<KEY, VAL, RET> = (key: KEY, value: VAL) -> RET
export type GenericPredicate = StringQuery | KeyValueBaseQuery<any, any, any> | BaseQuery<any, any>

-- Comparison/Selection types
export type Comparison<VAL> = StringQuery | BaseQuery<VAL, boolean>
export type Selection<VAL, RET> = StringQuery | BaseQuery<VAL, RET>

export type KeyValueComparison<KEY, VAL> = StringQuery | KeyValueBaseQuery<KEY, VAL, boolean>
export type KeyValueSelection<KEY, VAL, RET> = StringQuery | KeyValueBaseQuery<KEY, VAL, RET>

-- Concatenation types
export type ArrayParams = {any} | Array<any>
export type DictParams = {[any]: any} | Dictionary<any, any>

-- Note: Methods that modifies the table (e.g. Map, Flatten, GroupBy) type anottation is wrong because roblox thinks 
-- that "Array<U>" is recursive. It is better to have it as "Array<T>" and keep the annotation 
-- than using "Array<U"> without any annotation, but this is not ideal. It is also a problem for Dictionaries.

-- Enumerables
export type Array<T> = {
	-- Lazy
	Filter: (self: Array<T>, query: Comparison<T>) -> Array<T>,
	Map: <U>(self: Array<T>, query: Selection<T, U>) -> Array<T>,
	Unique: <U>(self: Array<T>, query: Selection<T, U>?) -> Array<T>,
	Take: (self: Array<T>, amount: number) -> Array<T>,
	Skip: (self: Array<T>, amount: number) -> Array<T>,

	-- Eager
	Flatten: <U>(self: Array<T>, query: Selection<T, {U}>) -> Array<T>,
	Reverse: (self: Array<T>) -> Array<T>,
	Shuffle: (self: Array<T>, seed: number?) -> Array<T>,
	Sort: (self: Array<T>, query: Selection<T, string | number>?) -> Array<T>,
	SortDescending: (self: Array<T>, query: Selection<T, string | number>?) -> Array<T>,
	ForEach: (self: Array<T>, query: BaseQuery<T, any>) -> nil,
	IsEmpty: (self: Array<T>) -> boolean,

	-- Search
	First: (self: Array<T>, query: Comparison<T>?) -> T?,
	Last: (self: Array<T>, query: Comparison<T>?) -> T?,
	Any: (self: Array<T>, query: Comparison<T>) -> boolean,
	All: (self: Array<T>, query: Comparison<T>) -> boolean,
	Contains: (self: Array<T>, value: T) -> boolean,

	-- Aggregators
	Count: (self: Array<T>, query: Comparison<T>?) -> number,
	Sum: (self: Array<T>, query: Selection<T, number>?) -> number,
	Average: (self: Array<T>, query: Selection<T, number>?) -> number,
	Min: (self: Array<T>, query: Selection<T, number>?) -> T?,
	Max: (self: Array<T>, query: Selection<T, number>?) -> T?,
	Reduce: <U>(self: Array<T>, query: (acc: U, item: T) -> U, accumulator: U) -> U,

	-- Output
	GroupBy: <U>(self: Array<T>, query: Selection<T, U>) -> {[U]: {T}},
	GetType: (self: Array<T>) -> "Array",
	ToTable: (self: Array<T>) -> {T},
}

export type Dictionary<K, V> = {
	-- Lazy
	Filter: (self: Dictionary<K, V>, query: KeyValueComparison<K, V>) -> Dictionary<K, V>,
	Map: <U>(self: Dictionary<K, V>, query: KeyValueSelection<K, V, U>) -> Dictionary<K, V>,
	Unique: <U>(self: Dictionary<K, V>, query: KeyValueSelection<K, V, U>?) -> Dictionary<K, V>,
	Take: (self: Dictionary<K, V>, query: number) -> Dictionary<K, V>,
	Skip: (self: Dictionary<K, V>, query: number) -> Dictionary<K, V>,
	
	-- Eager
	Flatten: <U>(self: Dictionary<K, V>, query: KeyValueSelection<K, V, {U}>) -> Array<U>,
	ForEach: (self: Dictionary<K, V>, query: KeyValueBaseQuery<K, V, any>) -> Dictionary<K, V>,
	IsEmpty: (self: Dictionary<K, V>) -> boolean,
	
	-- Search
	First: (self: Dictionary<K, V>, query: KeyValueComparison<K, V>) -> (K, V)?,
	Any: (self: Dictionary<K, V>, query: KeyValueComparison<K, V>) -> boolean,
	All: (self: Dictionary<K, V>, query: KeyValueComparison<K, V>) -> boolean,
	Contains: (self: Dictionary<K, V>, key: K) -> boolean,
	
	-- Aggregators
	Count: (self: Dictionary<K, V>, query: KeyValueComparison<K, V>?) -> number,
	Sum: (self: Dictionary<K, V>, query: KeyValueSelection<K, V, number>) -> number,
	Average: (self: Dictionary<K, V>, query: KeyValueSelection<K, V, number>) -> number,
	Min: (self: Dictionary<K, V>, query: KeyValueSelection<K, V, number>) -> (K, V)?,
	Max: (self: Dictionary<K, V>, query: KeyValueSelection<K, V, number>) -> (K, V)?,
	Reduce: <U>(self: Dictionary<K, V>, accumulator: U, query: (acc: U, key: K, value: V) -> U) -> U,
	
	-- Output
	GroupBy: <U>(self: Dictionary<K, V>, query: KeyValueSelection<K, V, U>) -> Dictionary<U, V>,
	GetType: (self: Dictionary<K, V>) -> "Dictionary",
	ToTable: (self: Dictionary<K, V>) -> {[K]: V},
}

return {}

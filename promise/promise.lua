local auxdbg  = require( "auxdbg"  )
---------------------------------------------------------------------------
-- 任务数据
local item_t = {
    cb = 0
}

---------------------------------------------------------------------------
-- promise数据的模板
local promise_t = {
    items = {},
    args = {},
    cb_ret = {},
    cb_err = 0,
    result = 0,
    count = 0,
    corout = 0
}

---------------------------------------------------------------------------
-- promise的元表，元表可减少promise实例开销
local _promise_t = {}

---------------------------------------------------------------------------
-- 执行一个任务, 并为任务提供一对执行成功和失败的回调
function _promise_t.call( self, item, args )
    function _resume( obj, success, args )
        -- print( 'resume: ', obj.corout, coroutine.running(), obj, debug.getinfo(1).currentline, obj.count )

        obj.args = { success = success, args = args }

        if obj.count == 0 then
            obj.count = obj.count + 1
        else
            obj.count = obj.count + 1
            coroutine.resume( obj.corout )
        end
    end

    function ok( self, ... )
        _resume( self.ins, true, { ... } )
    end

    function no( self, ... )
        _resume( self.ins, false, { ... } )
    end

    local ret = { pcall( item.cb, { ins = self, cur = item, ok = ok, no = no }, table.unpack( args ) ) }
    if ret[1] == false then self.cb_err( ret ); end
end

---------------------------------------------------------------------------
-- 递归查找第一个还未执行过的任务
function _promise_t.next( self, point )
    local ret = nil

    for i, item in ipairs( point.items ) do
        if item.flag == false then
            item.flag = true
            return item
        else
            if type( item.items ) == 'table' then
                ret = self:next( item )

                if ret ~= nil then
                    return ret
                end
            end
        end
    end

    return nil
end

---------------------------------------------------------------------------
-- 协程函数，递归查找下一个任务直到全部任务结束
function _promise_t.run( self )
    local task

    repeat
        -- 递归的查找下一个任务
        task = self:next( self )

        -- print( 'task:', task, self.corout, coroutine.running() )

        if task ~= nil then
            -- 运行任务
            self.call( self, task, self.args.args )

            -- print( 'wait:     ', self.corout, coroutine.running(), self, debug.getinfo(1).currentline, self.count )

            -- 等待任务执行成功的回调，并更新下一个任务的参数
            if self.count == 0 then
                self.count = self.count - 1
                coroutine.yield()
            else
                self.count = self.count - 1
            end
        end
        
    until( task == nil or self.args.success == false )

    -- 执行结束回调
    if type( self.cb_ret.cb ) == 'function' then
        local ret = { pcall( self.cb_ret.cb, self.args.success, table.unpack( self.args.args ) ) }
        if ret[0] == false then self.cb_err( ret ) end
    end
end

---------------------------------------------------------------------------
-- 在promise增加一个任务
function _promise_t.go( self, cb, pos )
    assert( cb ~= nil )
    assert( type( cb ) == 'function' )

    if pos == nil then pos = self; end
    if pos.items == nil then pos.items = {}; end

    local item = { cb = cb, flag = false }
    table.insert( pos.items, item )

    -- print( 'add cb:', self, item, cb, pos )

    return self
end

---------------------------------------------------------------------------
-- 在promise增加一个任务
function _promise_t.error( self, cb )
    assert( type( cb ) == 'function' )

    self.cb_err = cb

    return self
end

---------------------------------------------------------------------------
-- promise的最后一个任务, 注意用户必须调用promise:result( cb )明确指明结束过程才会启动promise
function _promise_t._result( self, args )
    return function( self, cb )
        assert( cb == nil or type( cb ) == 'function' )
        self.cb_ret = { cb = cb, flag = false }
        self.args = { success = true, args = args }

        self.corout = coroutine.create( function( self ) self:run() end )

        -- auxdbg.print( self )
        -- print( 'result: ', coroutine.running(), self.corout )

        coroutine.resume( self.corout, self )
    end
end

---------------------------------------------------------------------------
-- 深复制对象
function deep_copy( source )
    local target

    if type( source ) == 'table' then
        target = {}

        for k, v in pairs( source ) do
            target[ k ] = deep_copy( v )
        end
    else
        target = source
    end

    return target
end

---------------------------------------------------------------------------
-- 请求新promise实例
function _promise_t.create( self, ... )
    local ret = setmetatable( deep_copy( promise_t ), { __index = _promise_t } )

    ret.result = ret._result( ret, { ... } )

    return ret
end

---------------------------------------------------------------------------
return _promise_t

local promise = require( "promise" )

---------------------------------------------------------------------------
-- 静态声明测试程序: 计数任务
function test_static( self )
    print( '------------------ test static --------------------------' )

    -- 声明promise实例
    local pme = promise:create( 0 )
    
    -- 声明错误处理回调，所有任务是通过pcall执行，因此错误回调参数就是pcall的返回值
    pme:error( function ( err ) print( 'error:', table.unpack( err ) ); end)

    pme:go( function ( ctxx, a )
        local pp = promise:create( a )

        pp:error( function ( err ) print( 'error:', table.unpack( err ) ); ctxx:no( a ); end )
        pp:go( function ( ctx, b ) print( 'sub step:', b + 1 ); ctx:ok( b + 1 ); end)
        pp:go( function ( ctx, b ) print( 'sub step:', b + 1 ); ctx:ok( b + 1 ); end)
        pp:go( function ( ctx, b ) print( 'sub step:', b + 1 ); ctx:ok( b + 1 ); end)

        pp:result( function ( state, b ) print( 'sub count:', b, state ); ctxx:ok( b ); end)
    end )

    -- 3次任务把初值从0计算到3
    pme:go( function ( ctx, a ) print( 'step:', a + 1 ); ctx:ok( a + 1 ); end)
    pme:go( function ( ctx, a ) print( 'step:', a + 1 ); ctx:ok( a + 1 ); end)
    pme:go( function ( ctx, a ) print( 'step:', a + 1 ); ctx:ok( a + 1 ); end)

    -- 验证异常
    -- pme:go( function ( ctx, a ) print( 'step:', 'error' ); ctx:ok( a[0] ); end)

    pme:result( function ( state, a ) print( 'count:', a, state ); end)

    print( '------------------ test static --------------------------\n' )
end

---------------------------------------------------------------------------
-- 动态声明任务测试程序: 嵌套数列求和
function test_dynamic( self )
    print( '------------------ test dynamic -------------------------' )

    -- 被求和的列表
    local data = {
        { 1, 2, 3 },
        { 1, 2, 3 },
        { 1, 2, 3 }
    }

    -- 声明promise实例
    local pme = promise:create( data )

    -- 求和结果
    local ret = 0

    -- promise每次求和的迭代函数, 每次求和如果未结束侧追加新的任务继续计算
    function sum( ctx, first, ... )
        if first == nil then ctx:ok(); return; end

        if type( first ) == 'table' then
            pme:go( sum, ctx.cur )

            local na = { table.unpack( first ) }

            for i, v in ipairs( { ... } ) do
                table.insert( na, v )
            end

            ctx:ok( table.unpack( na ) )
        else
            assert( type( first ) == 'number' )

            print( 'step: ', ret .. ' += ' .. first )

            ret = ret + first;

            pme:go( sum )
            ctx:ok( ... )
        end
    end
    
    pme:go( sum )
    pme:result( function() print( 'sum = ', ret ); end )

    print( '------------------ test dynamic -------------------------\n' )
end

---------------------------------------------------------------------------
-- 运行
test_static()
test_dynamic()
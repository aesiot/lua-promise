# lua-promise

Promise库的lua版，可支持嵌套调用的同步

## 1. 导入

```
local promise = require( "promise" )
```

## 2. 创建

```
local pme = promise:create( {} )
```

参数为任何可计算结果的表达式，做为用户给后续声明任务的初始数据。

## 3. 声明任务

```
pme:go( function ( ctx, arg )
    local ret = 0;

    --任务过程。。。
    ret = ret + 1;

    --如果任务失败
    if false then
        ctx.no();
    end

    --任务完成, 返回结果
    ctx.ok( ret );
end )
```

* promise.go: 在任务树首层尾部声明新的任务，只需要一个任务函数做为参数，函数签名需要满足： function( ctx, arg ) end
* ctx: 是任务上下文对象，包含反馈任务执行成功或失败的调用，调用可接收用户需要向下传递的数据。
* arg: 任务树中前级任务返回的结果，如果是第一个任务则为创建promise时用户指定的初始参数。

## 3. 声明嵌套子任务

声明子任务的签名形式：

```
pme:go( function( ctx2, arg2 ) end, pos )
```

典型的结构如下：

```
pme:go( function ( ctx1, arg )
    --任务过程 。。。

    --需要嵌套子任务：
    pme:go( function( ctx2, arg2 )
        --子任务过程 。。。

        --如果子任务失败
        if false then
            ctx2.no();
            ctx1.no();
        end

        --子任务完成
        ctx2.ok();
        ctx1.ok();
    end, ctx1.cur )
end )
```

promise.go: 在任务树中声明新的下级子任务，需要任务函数和子任务插入位置做为参数:
* 函数签名需要满足： function( ctx, arg ) end
* 子任务插入位置一般是做为当前任务的子任务，则使用当前任务上下文的： ctx.cur

需要注意： 父子任务的上下文参数命名覆盖往往容易产生问题, 如这里命名为ctx1和ctx2以避免命名覆盖。

## 4. 同步结果

```
pme:result( function ( state, arg ) print( 'count:', arg, state ); end )
```

如果任务树执行结束则发起result调用：
* 任务树所有任务成功执行state为true，否则为falsee;
* 任务树最后一个任务返回的结果arg;

## 5. 示例

以下示例演示两种方式使用promise对3维数组求和，并打印出计算过程：

```
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
```

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

interface IChronosV3DysonVault {


event Approval( address indexed owner,address indexed spender,uint256 value ) ;
event Deposit( address indexed sender,uint256 _token0Amount,uint256 _token1Amount,uint256 shares,uint256 totalLiquidity ) ;
event Initialized( uint8 version ) ;
event OwnershipTransferred( address indexed previousOwner,address indexed newOwner ) ;
event Transfer( address indexed from,address indexed to,uint256 value ) ;
event VaultPaused( uint256 block,uint256 timestamp ) ;
event Withdraw( address indexed sender,uint256 _expectA0,uint256 _expectA1,uint256 _shares ) ;
event ZapIn( address indexed sender,uint256 _tokenAmount,address _token,bytes _data,address _oneInchRouter ) ;
fallback () external payable;
function __UniswapVault_init( string memory _name,string memory _symbol,address _pool,address _governance,address _timelock,address _controller,address _iUniswapCalculator,address _wNative ) external   ;
function allowance( address owner,address spender ) external view returns (uint256 ) ;
function approve( address spender,uint256 amount ) external  returns (bool ) ;
function balanceOf( address account ) external view returns (uint256 ) ;
function calculateZapProportion( uint256 _token0Amount,uint256 _token1Amount ) external view returns (uint256 , address , address ) ;
function controller(  ) external view returns (address ) ;
function controllerType(  ) external view returns (int8 ) ;
function currentTick(  ) external view returns (int24 ) ;
function decimals(  ) external view returns (uint8 ) ;
function decreaseAllowance( address spender,uint256 subtractedValue ) external  returns (bool ) ;
function deposit( uint256 _token0Amount,uint256 _token1Amount,uint256 _minLiquidity,bool _init ) external payable returns (uint256 ) ;
function earn(  ) external   ;
function getLowerTick(  ) external view returns (int24 ) ;
function getProportion(  ) external view returns (uint256 ) ;
function getRatio(  ) external view returns (uint256 ) ;
function getUpperTick(  ) external view returns (int24 ) ;
function governance(  ) external view returns (address ) ;
function increaseAllowance( address spender,uint256 addedValue ) external  returns (bool ) ;
function investedUnderlyingBalance(  ) external view returns (uint256 ) ;
function liquidityOfThis(  ) external view returns (uint256 ) ;
function name(  ) external view returns (string memory ) ;
function onERC721Received( address ,address ,uint256 ,bytes memory  ) external pure returns (bytes4 ) ;
function owner(  ) external view returns (address ) ;
function paused(  ) external view returns (bool ) ;
function pool(  ) external view returns (address ) ;
function renounceOwnership(  ) external   ;
function setController( address _controller ) external   ;
function setControllerType( int8 _controlType ) external   ;
function setGovernance( address _governance ) external   ;
function setPaused( bool _paused ) external   ;
function setTimelock( address _timelock ) external   ;
function strategy(  ) external view returns (address ) ;
function symbol(  ) external view returns (string memory ) ;
function timelock(  ) external view returns (address ) ;
function token0(  ) external view returns (address ) ;
function token1(  ) external view returns (address ) ;
function totalLiquidity(  ) external view returns (uint256 ) ;
function totalSupply(  ) external view returns (uint256 ) ;
function transfer( address to,uint256 amount ) external  returns (bool ) ;
function transferFrom( address from,address to,uint256 amount ) external  returns (bool ) ;
function transferOwnership( address newOwner ) external   ;
function underlying(  ) external  returns (address ) ;
function uniswapCalculator(  ) external view returns (address ) ;
function univ3Router(  ) external view returns (address ) ;
function wNative(  ) external view returns (address ) ;
function withdraw( uint256 _shares ) external   ;
function withdrawAll(  ) external   ;
function zapIn( uint256 _tokenAmount,address _token,bytes memory _data,address _oneInchRouter ) external payable  ;
receive () external payable;
}


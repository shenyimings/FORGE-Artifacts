/*

$$\   $$\       $$$$$$$$\       $$\   $$\ 
$$ |  $$ |      $$  _____|      $$ |  $$ |
$$ |  $$ |      $$ |            $$ |  $$ |
$$$$$$$$ |      $$$$$\          $$$$$$$$ |
$$  __$$ |      $$  __|         $$  __$$ |
$$ |  $$ |      $$ |            $$ |  $$ |
$$ |  $$ |      $$ |            $$ |  $$ |
\__|  \__|      \__|            \__|  \__|
                                          
                                          
                                          

*/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
interface IERC721 is IERC165 {

    function transferFrom(address from, address to, uint256 tokenId) external;


}
interface IERC20 {
    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
interface ISwapPair {
    function mint(address to) external returns (uint liquidity);
    function sync() external;
}

interface ISwapRouter {
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface INonfungiblePositionManager {

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
    external
    payable
    returns (uint256 amount0, uint256 amount1);

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function increaseLiquidity(IncreaseLiquidityParams calldata params)
    external
    payable
    returns (
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    function positions(uint256 tokenId)
    external
    view
    returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );
}

interface IV3CALC{
    function principal(
        int24 _tickLower,
        int24 _tickUpper,
        uint128 liquidity
    ) external view returns (uint256 amount0, uint256 amount1);
}

abstract contract Ownable {
    address internal _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = msg.sender; 
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "!owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "new is 0");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract HFHMidWallet{
    address public router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address public wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public usdt = 0x55d398326f99059fF775485246999027B3197955;
    address public lp;
    address public hfhContract;
    constructor(address _hfhContract,address _lp){
        hfhContract = _hfhContract;
        lp =_lp;
    }

    modifier onlyHfhContract{
        require(msg.sender == hfhContract,'only HFH');
        _;
    }

    function swapAndliq(uint256 tokenAmount,address _to) external onlyHfhContract{

        uint256 swapAmount = tokenAmount/2;
        IERC20(hfhContract).approve(router, swapAmount);
        address[] memory path = new address[](2);
        path[0] = hfhContract;
        path[1] = wbnb;
        ISwapRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(swapAmount,0,path,address(this),block.timestamp+1000);

        uint256 addliqBnb = IERC20(wbnb).balanceOf(address(this));
        uint256 addliqHfh = tokenAmount - swapAmount;
        IERC20(wbnb).transfer(lp, addliqBnb);
        IERC20(hfhContract).transfer(lp, addliqHfh);
        ISwapPair(lp).mint(_to);
    }


    function swapToUsdt(uint256 tokenAmount,address toReward,address toMarket) external onlyHfhContract{
        uint256 swapAmount = tokenAmount;
        IERC20(hfhContract).approve(router, swapAmount);
        address[] memory path = new address[](3);
        path[0] = hfhContract;
        path[1] = wbnb;
        path[2] = usdt;
        uint256 startU = IERC20(usdt).balanceOf(address(this));
        ISwapRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(swapAmount,0,path,address(this),block.timestamp+1000);
        uint256 endU = IERC20(usdt).balanceOf(address(this));
        if(endU>startU){
            uint256 swapU = endU-startU;
            uint256 toR = swapU* 40 /90;
            uint256 toM = swapU - toR;
            if(toR>0){
                IERC20(usdt).transfer(toReward,toR);
            }
            if(toM>0){
                IERC20(usdt).transfer(toMarket,toM);
            }
        }
    }

}

contract HFH is IERC20, Ownable{

    string private _name = "HFH";
    string private _symbol = "HFH";
    uint8 private _decimals = 18;
    uint128 public lpAmounts;   
    uint256 private _totalsupply =21000000 * 10 ** 18;
    uint256 private _farmingsupply =20500000 * 10 ** 18;
    uint256 private _firstlpsupply = 500000 * 10 ** 18;
    uint256 public constant MAX = ~uint256(0);  
    uint256 private constant MASTERCHEF_SUSHI_PER_BLOCK = 0.3472222222222222 * 1e18;   
    uint256 private constant ACC_SUSHI_PRECISION = 1e12;    
    uint256 public dayBlock = 28800;        
    uint256 public _tokenId;    
    uint256 public lpBNBAmounts; 
    uint256 public buyFeeAmounts;
    uint256 public sellFeeAmounts;
    uint256 public staticSupply;   
    uint256 public inviteSupply;   
    uint256 public totalAllocPoint; 
    uint256 public startTime; 
    uint256 public  totalUser;  
    uint256 public  totalInvestTime;
    uint256 public  totalValue;
    uint256 public totalPreBuyAmount;   
    uint256 public nftRewardAmount; 
    uint256[] public shareRateList =[15,15,15,5,5,5,5,5,5,5,4,4,4,4,4];
    uint256 public burnRate;    
    uint256 public totalBurnRate; 
    uint256 public nextBurnTime;
    mapping(address => uint256) private _balances;     
    mapping(address => mapping(address => uint256)) private _allowances;  
    mapping(address=>mapping(address=>bool)) public bindState; 
    mapping(address => uint256) public userInviteAddr; 
    mapping(address => address[]) public userInviteAddrList;
    mapping(address=>address) public userTop;  
    mapping(address => uint256) public userTotalShareAddr; 
    mapping(address => bool) public noFirstInvite;
    mapping(address => uint256) public userInvestStaticAmount;
    mapping(address => uint256) public userShareLevel;
    mapping(address => uint256) public userClaimShareBNBAmounts;
    mapping(address => uint256) public userPrebuyBNBAmount; 
    mapping(address => uint256) public userperbuyBNBAmount;
    mapping(address => uint256) public userLastActionBlock;
    mapping(address => uint256) public userClaimedStaticRewards;
    mapping(address => uint256) public userClaimedInviteRewards;
    address public dev;     
    address public burnManage; 
    address public factory = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;  
    address public router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;     
    address public wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;      
    address public bnbPair;
    address public wallet = 0x36696169C63e42cd08ce11f5deeBbCeBae652050;     
    address public deadAddr = 0x000000000000000000000000000000000000dEaD;    
    address public V3Manage = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;   
    HFHMidWallet public midWallet;
    address public v3_position_calc;
    address public noLevelFund; 
    address public nftRewards;  
    address public nodeRewards;
    address public buyFeeLpManage;
    address public sellFeeRewards;
    address public sellFeeMarket;
    address public firstAddr;
    

    
    struct UserInfo {
        uint256 amount;     
        uint256 rewardDebt;  
    }
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    
    struct PoolInfo {
        uint256 accSushiPerShare;
        uint256 lastRewardBlock;
        uint256 allocPoint;
    }
    PoolInfo[] public poolInfo;
    
    bool public investStatus;   
    bool public openBuy;
    bool public lockV3NFT;
    bool inswap; 
    constructor (
    ){
        dev=msg.sender;
        _balances[address(this)] = _farmingsupply;
        emit Transfer(address(0), address(this), _farmingsupply);
        _balances[dev] = _firstlpsupply;
        emit Transfer(address(0), dev, _firstlpsupply);

        (address token3, address token4) = sortTokens(wbnb, address(this));
        bnbPair = address(uint160(uint(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token3, token4)),
            hex'00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5'
        )))));

        midWallet = new HFHMidWallet(address(this),bnbPair);

    }


    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalsupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        if (_allowances[sender][msg.sender] != MAX) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        }
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

       
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private{
        require(from != to,"Same");
        require(amount >0 ,"Zero");
        uint256 balance = _balances[from];
        require(balance >= amount, "balance Not Enough");
        _balances[from] = _balances[from] - amount;

        if(inswap || (to == dev && !investStatus) || (from == dev && !investStatus)){
            _balances[to] +=amount;
            emit Transfer(from, to, amount);
            return;
        }


        if(from == bnbPair){
            require(openBuy,'Buy Close');
            uint256 buyFeeAmount = amount * 9 / 100;
            uint256 transBuyAmount = amount - buyFeeAmount;
            buyFeeAmounts += buyFeeAmount;
            _balances[address(midWallet)] +=buyFeeAmount;
            emit Transfer(from, address(midWallet), buyFeeAmount);
            _balances[to] +=transBuyAmount;
            emit Transfer(from, to, transBuyAmount); 
            return;

        }

        if(to == address(this)){
            
            address sender = msg.sender;
            require(sender == from,"Bot");
            require(sender == tx.origin,'BOT');
            _balances[address(this)] +=amount;
            emit Transfer(from, to, amount);

            uint256 userInvestAmount = userInvestStaticAmount[sender];
            if(userInvestAmount == 0 || userLastActionBlock[sender]==0 ||  (userLastActionBlock[sender] + dayBlock ) > block.number){

                return;
            }
            uint256 userInvestDay = (block.number - userLastActionBlock[sender]) / dayBlock;    

            if(userPrebuyBNBAmount[sender] >0 && (userPrebuyBNBAmount[sender] >= userperbuyBNBAmount[sender]) && (userInvestDay >= 1)){
                
                uint256 preNeedBuy = userperbuyBNBAmount[sender] * userInvestDay;
                if(preNeedBuy >userPrebuyBNBAmount[sender]){
                    preNeedBuy = userPrebuyBNBAmount[sender];
                }
                claimRewardsBuy(preNeedBuy);
                uint256 endPre = userPrebuyBNBAmount[sender] - preNeedBuy;
                userPrebuyBNBAmount[sender] = endPre;

            }

            harvest(0,sender);
            harvest(1,sender);
            userLastActionBlock[sender] = block.number;

            return;
        }


        uint256 sellFeeAmount;
        if(to == bnbPair){
            sellFeeAmount= amount * 9 / 100;

        }

        if(sellFeeAmount>0){
            _balances[address(midWallet)] +=sellFeeAmount;
            sellFeeAmounts += sellFeeAmount;
            emit Transfer(from, address(midWallet), sellFeeAmount);
            swapFee();
        }
        uint256 transAmount = amount - sellFeeAmount;
        _balances[to] +=transAmount;
        emit Transfer(from, to, transAmount); 

        bool canInvite = (userTop[from] !=address(0)
            && userTop[to] == address(0)
            && to !=address(1)
            && !isContract(from)
            && !isContract(to)
            && from != to 
        );

        if(canInvite){
            bindState[from][to] = true;
        }

        bool canByInvite = (userTop[from] == address(0)
            && userTop[to] !=address(0)
            && !isContract(from)
            && !isContract(to)
            && from != to
            && bindState[to][from]
        );

        if(canByInvite){
            userTop[from] = to;
            userInviteAddr[to] ++;
            userInviteAddrList[to].push(from);
        }

        return;



    }
    
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    
    function internalBuy(uint256 bnbAmount) private{
        require(!inswap,"inSwap");
        inswap =true;
        address[] memory path = new address[](2);
        path[0] = wbnb;
        path[1] = address(this);

        ISwapRouter(router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: bnbAmount}(0, path, deadAddr, block.timestamp+1000);
        inswap=false;
    } 

    function claimRewardsBuy(uint256 bnbAmount) private{
        require(!inswap,"inSwap");
        inswap =true;

        (,,,,,int24 tickLower,int24 tickUpper,uint128 liquidity,,,,) = INonfungiblePositionManager(V3Manage).positions(_tokenId);

        (,uint256 amountBNB) = IV3CALC(v3_position_calc).principal(tickLower,tickUpper,liquidity);

        require(amountBNB >= bnbAmount,'LOW BNB');
        require(liquidity>0,'Position Low');

        uint256 calcRes = bnbAmount * liquidity / amountBNB;
        uint128 deLpAmunt = uint128(calcRes)+1;
        if(deLpAmunt>liquidity){
            deLpAmunt = liquidity;
        }
        (,uint256 amount1) = INonfungiblePositionManager(V3Manage).decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams({
             tokenId:_tokenId,
             liquidity:deLpAmunt,
             amount0Min:0,
             amount1Min:0,
             deadline:block.timestamp+1000
        }));
        require(amount1>0,'Position LOW BNB');
        INonfungiblePositionManager(V3Manage).collect(INonfungiblePositionManager.CollectParams({
            tokenId:_tokenId,
            recipient:address(this),
            amount0Max:340282366920938463463374607431768211455,
            amount1Max:340282366920938463463374607431768211455
        }));

        if(lpBNBAmounts > amount1){
            uint256 endBnb = lpBNBAmounts - amount1;
            lpBNBAmounts =endBnb;
        }
        if(lpAmounts > deLpAmunt){
            uint128 endLp  = lpAmounts - deLpAmunt;
            lpAmounts = endLp;
        }
        IERC20(wbnb).approve(router, amount1);
        address[] memory path = new address[](2);
        path[0] = wbnb;
        path[1] = address(this);
        ISwapRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(amount1,0,path,deadAddr,block.timestamp+1000);
        inswap=false;
    }

    
    function swapFee() private{
        require(!inswap,"inSwap");
        inswap =true;
        uint256 toitalBuyFee = buyFeeAmounts;
        if(toitalBuyFee>0){
            uint256 midBalBuy = IERC20(address(this)).balanceOf(address(midWallet));
            if(toitalBuyFee>=midBalBuy){
                toitalBuyFee =midBalBuy;
            }
            midWallet.swapAndliq(toitalBuyFee,buyFeeLpManage);
            buyFeeAmounts = 0;
        }
        uint256 totalSellFee = sellFeeAmounts;
        if(totalSellFee>0){
            uint256 midBalSell = IERC20(address(this)).balanceOf(address(midWallet));
            if(totalSellFee>=midBalSell){
                totalSellFee =midBalSell;
            }
            midWallet.swapToUsdt(totalSellFee,sellFeeRewards,sellFeeMarket);
            sellFeeAmounts =0;
        }
        inswap =false;
    }



    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'PancakeLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'PancakeLibrary: ZERO_ADDRESS');
    }


    function openProject(uint256 _id,address _calc)public onlyOwner{
        require(!investStatus,'Start');
        investStatus = true;
        _tokenId = _id;
        v3_position_calc = _calc;

        totalAllocPoint = 10000;
        poolInfo.push(PoolInfo({
            allocPoint: 7000,
            lastRewardBlock: block.number,
            accSushiPerShare: 0
        }));
        poolInfo.push(PoolInfo({
            allocPoint: 3000,
            lastRewardBlock: block.number,
            accSushiPerShare: 0
        }));
    }

    function openBuyState() public onlyOwner{
        require(!openBuy,'Open');
        openBuy = true;
    }

    function setProjectInfo(address[] memory _projectAddrList,uint256[] memory _burnInfo) public onlyOwner{
        noLevelFund = _projectAddrList[0];
        nftRewards = _projectAddrList[1];
        nodeRewards = _projectAddrList[2];
        buyFeeLpManage = _projectAddrList[3];
        sellFeeRewards = _projectAddrList[4];
        sellFeeMarket = _projectAddrList[5];
        burnManage = _projectAddrList[6];
        firstAddr = _projectAddrList[7];
        burnRate = _burnInfo[0];
        totalBurnRate = _burnInfo[1];
        _tokenId = _burnInfo[2];
        startTime = _burnInfo[3];
        userTop[dev] =address(1);
        userTop[firstAddr] = dev;
    }

    function lockV3()public onlyOwner{
        require(!lockV3NFT,'LOCK');
        lockV3NFT = true;
    }


    function pendingSushi(uint256 _pid, address _user) external view returns (uint256 pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accSushiPerShare = pool.accSushiPerShare;
        uint256 lpSupply = staticSupply;
        if(_pid == 1){
            lpSupply = inviteSupply;
        }
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blocks = block.number - pool.lastRewardBlock;

            uint256 sushiReward = blocks * MASTERCHEF_SUSHI_PER_BLOCK * pool.allocPoint / totalAllocPoint;

            accSushiPerShare = accSushiPerShare + (sushiReward * (ACC_SUSHI_PRECISION) / lpSupply);
        }
        pending = (user.amount * accSushiPerShare / ACC_SUSHI_PRECISION) - user.rewardDebt;
    }

    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    function updatePool(uint256 pid) public returns (PoolInfo memory pool) {
        require(pid<2,'No Pool');
        pool = poolInfo[pid];
        if (block.number > pool.lastRewardBlock) {
            uint256 lpSupply = staticSupply;
            if(pid == 1){
                lpSupply = inviteSupply;
            }
            if (lpSupply > 0) {
                uint256 blocks = block.number - pool.lastRewardBlock;
                uint256 sushiReward = blocks * MASTERCHEF_SUSHI_PER_BLOCK * pool.allocPoint / totalAllocPoint;
                pool.accSushiPerShare = pool.accSushiPerShare + (sushiReward * (ACC_SUSHI_PRECISION) / lpSupply);
            }
            pool.lastRewardBlock = block.number;
            poolInfo[pid] = pool;
        }
    }


    function deposit(uint256 pid, uint256 amount, address to) internal {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][to];

        // Effects
        user.amount = user.amount + amount;
        user.rewardDebt = user.rewardDebt + (amount * (pool.accSushiPerShare) / ACC_SUSHI_PRECISION);

        if(pid ==0){
            staticSupply +=amount;
        }
        if(pid ==1){
            inviteSupply +=amount;
        }
    }


    function harvest(uint256 pid, address to) internal {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][to];
        uint256 accumulatedSushi = user.amount * pool.accSushiPerShare / ACC_SUSHI_PRECISION;
        uint256 _pendingSushi = accumulatedSushi - user.rewardDebt;

        // Effects
        user.rewardDebt = accumulatedSushi;

        // Interactions
        if (_pendingSushi != 0) {
            uint256 endSendDnhAmount = _balances[address(this)] - _pendingSushi;
            _balances[address(this)] = endSendDnhAmount;
            _balances[to] += _pendingSushi;
            emit Transfer(address(this), to, _pendingSushi);
            if(pid==0){
                userClaimedStaticRewards[to] +=_pendingSushi;
            }
            if(pid ==1){
                userClaimedInviteRewards[to] +=_pendingSushi;
            }
        }
    }


    receive() external payable{
        address sender = msg.sender;  
        uint256 fromBNBAmount = msg.value; 
        bool isBot = isContract(sender);  
        if(isBot  || (tx.origin != sender)){
            return; 
        }
        require(investStatus,"NOT OPEN !"); 
        require(sender != dev,"DEV Forbid");    
        require(fromBNBAmount >= 1 ether,"Min Invest Value"); 
        
        address top = userTop[sender];  
        require(top != address(0),'not bind');  

        
        userInvestStaticAmount[sender]  +=fromBNBAmount;
        uint256 myLevel = userShareLevel[sender];
        if(myLevel <3){
            uint256 myStaticValues = userInvestStaticAmount[sender];
            uint256 myShareAmounts = userTotalShareAddr[sender];
            
            if(myLevel == 2){
                
                if(myStaticValues >= 5 ether && myShareAmounts>=5){
                    userShareLevel[sender] =3;
                }
                
            }
            if(myLevel == 1){
                
                if(myStaticValues >= 3 ether && myShareAmounts>=3){
                    userShareLevel[sender] =2;
                }
                if(myStaticValues >= 5 ether && myShareAmounts>=5){
                    userShareLevel[sender] =3;
                }
            }
            if(myLevel == 0){
                
                if(myStaticValues >= 1 ether && myShareAmounts>=1){
                    userShareLevel[sender] =1;
                }
                if(myStaticValues >= 3 ether && myShareAmounts>=3){
                    userShareLevel[sender] =2;
                }
                if(myStaticValues >= 5 ether && myShareAmounts>=5){
                    userShareLevel[sender] =3;
                }
                
            }
        }

        
    
        if(! noFirstInvite[sender]){
            userTotalShareAddr[top] ++;
            totalUser++;
            noFirstInvite[sender] = true;
        }

        uint256 topLevel = userShareLevel[top]; 
        if(topLevel<3){
            uint256 topStaticValues = userInvestStaticAmount[top];
            uint256 topShareAmounts = userTotalShareAddr[top];

            if(topLevel == 2){

                if(topStaticValues >= 5 ether && topShareAmounts>=5){
                    userShareLevel[top] =3;
                }
                
            }
            if(topLevel == 1){

                if(topStaticValues >= 3 ether && topShareAmounts>=3){
                    userShareLevel[top] =2;
                }
                if(topStaticValues >= 5 ether && topShareAmounts>=5){
                    userShareLevel[top] =3;
                }
            }
            if(topLevel == 0){

                if(topStaticValues >= 1 ether && topShareAmounts>=1){
                    userShareLevel[top] =1;
                }
                if(topStaticValues >= 3 ether && topShareAmounts>=3){
                    userShareLevel[top] =2;
                }
                if(topStaticValues >= 5 ether && topShareAmounts>=5){
                    userShareLevel[top] =3;
                }
                
            }
        }

        uint256 shareRewardsBNB = fromBNBAmount * 500 /1000;
        address sTop = userTop[sender];
        for(uint256 i=0;i<shareRateList.length;i++){
            uint256 preShareAmount = shareRewardsBNB * shareRateList[i] /100;
            uint256 stopLevel = userShareLevel[sTop];
            uint256 k=0;
            if(stopLevel ==1){
                k = 3;
            }
            if(stopLevel ==2){
                k = 10;
            }
            if(stopLevel ==3){
                k = 15;
            }
            if(k>i){
                
                deposit(1,preShareAmount,sTop);

                uint256 userCanClaimdShareBNB = userInvestStaticAmount[sTop] *3;    
                uint256 userClaimdShareBNBAmounts = userClaimShareBNBAmounts[sTop]; 
                uint256 userRealCanClaimAmounts =0;
                uint256 overflowAmounts = 0;
                if(userCanClaimdShareBNB > userClaimdShareBNBAmounts){ 
                    
                    userRealCanClaimAmounts = userCanClaimdShareBNB - userClaimdShareBNBAmounts;

                }
                if(userRealCanClaimAmounts >= preShareAmount){
                    userRealCanClaimAmounts = preShareAmount;
                }
                if(preShareAmount >userRealCanClaimAmounts){
                    overflowAmounts =preShareAmount- userRealCanClaimAmounts;
                }

                if(userRealCanClaimAmounts>0){
                    payable(sTop).transfer(userRealCanClaimAmounts);
                    userClaimShareBNBAmounts[sTop] += userRealCanClaimAmounts;
                }
                if(overflowAmounts>0){
                    payable(noLevelFund).transfer(preShareAmount);
                }

            }else {
                payable(noLevelFund).transfer(preShareAmount);
            }
            sTop = userTop[sTop];
        }

        userPrebuyBNBAmount[sender] += (fromBNBAmount*295/1000);    
        userperbuyBNBAmount[sender] = userPrebuyBNBAmount[sender] /59;
        uint256 firstBuyValue = fromBNBAmount*5/1000;
        internalBuy(firstBuyValue); 
        userLastActionBlock[sender] = block.number;
        totalPreBuyAmount += fromBNBAmount*300/1000;
        nftRewardAmount +=(fromBNBAmount*100/1000);
        payable(nftRewards).transfer(fromBNBAmount*100/1000); 
        payable(nodeRewards).transfer(fromBNBAmount*100/1000); 

        uint256 nowTime = block.timestamp;
        uint256 calcDay = (nowTime - startTime) / 86400;
        uint256 proofRewards = 0;
        if(calcDay>0){
            proofRewards = fromBNBAmount * calcDay /10000;
        }
        uint256 depositValue = fromBNBAmount + proofRewards;
        deposit(0,depositValue,sender);

        totalInvestTime++;
        totalValue +=fromBNBAmount;

        uint256 endBnb = address(this).balance;
        if(endBnb>0){
            (uint128 lpAmount,,uint256 amount1) = INonfungiblePositionManager(V3Manage).increaseLiquidity{value: endBnb}(INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId:_tokenId,
                amount0Desired:0,
                amount1Desired:endBnb,
                amount0Min:0,
                amount1Min:endBnb,
                deadline:block.timestamp+1000
            }));
            require(lpAmount>0 && amount1 == endBnb,'DepositV3 Error');
            lpBNBAmounts +=endBnb;
            lpAmounts += lpAmount;
        }

        if(balanceOf(address(this)) > 1e14){
            _transfer(address(this),sender,1e14);
        }
        return;

    }

    function burnSwap() public{
        require(msg.sender == burnManage,'only burnManage');
        uint256 nowBurnTime = block.timestamp;
        require(nowBurnTime >= nextBurnTime,'waiting time');
        nextBurnTime = nowBurnTime + 1 days;
        uint256 lpBal = _balances[bnbPair];
        uint256 burnAmounts = lpBal*burnRate/totalBurnRate;
        uint256 endBal = lpBal - burnAmounts;
        _balances[bnbPair] = endBal;
        _balances[deadAddr] = _balances[deadAddr] + burnAmounts;
        emit Transfer(bnbPair, deadAddr, burnAmounts);
        ISwapPair(bnbPair).sync();
    }


    function withdrawV3NFT(address to) external onlyOwner{
        require(!lockV3NFT,'LOCK');
        IERC721(V3Manage).transferFrom(address(this), to, _tokenId);
    }

    function claimErrorToken(address _errorToken)external {
        require(_errorToken != address(this),'error');
        require(msg.sender == dev,'only dev');
        IERC20(_errorToken).transfer(msg.sender, IERC20(_errorToken).balanceOf(address(this)));
    }
}
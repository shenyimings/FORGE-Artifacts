/*
$$$$$$$\        $$\   $$\       $$\   $$\ 
$$  __$$\       $$$\  $$ |      $$ |  $$ |
$$ |  $$ |      $$$$\ $$ |      $$ |  $$ |
$$ |  $$ |      $$ $$\$$ |      $$$$$$$$ |
$$ |  $$ |      $$ \$$$$ |      $$  __$$ |
$$ |  $$ |      $$ |\$$$ |      $$ |  $$ |
$$$$$$$  |      $$ | \$$ |      $$ |  $$ |
\_______/       \__|  \__|      \__|  \__|
                                                                  
Bull coins technology team adheres to the original intention of decentralization.  
It stands for smart contract.  
It is a new development of decentralized blockchain that simplifies formal verification by establishing a true digital federation to manage itself.  
This technology mathematically guarantees the accuracy of transaction codes and improves the security of smart contracts.  
It is a universal and self-evolving encrypted digital ledger.  
The biggest advantage of Bull coins is decentralized contract technology, which implements various operations on the conventional blockchain in the form of simple functional modules.  
The latest generation of mining models in the world is coming, taking you through bulls and bears, standing at the forefront of the bull market, and leading the bull market to come!  
The Bull coins-Master technical team develops the latest mining technology, which is based on the second-layer network foundation and manages the market value through contracts to solve the problems of mining costs and token market value. 
This mining method is referred to as POH.
The output needs to be output through the contract, and the automatic pulling mechanism of output execution will start the journey of market value take-off!  
Bull coins-Master contract mining POH has core value advantages and solves the pain points of previous generations of mining. 
There is no need to purchase hardware equipment, no need to purchase pledged coins to lock up, and solves the problems of high costs and shrinkage of pledged coins.  
All costs of POH mining are used in the primary market, the decentralized exchange permanently locks the pool, there is no chip reservation and concentration issues, perfect dispersion and super consensus mechanism, the secondary market profits while ensuring the return of the pool, ensuring that every  A miner has stable profits!  
Looking back on 2017 to the present, mining is the strongest consensus in the entire blockchain industry. 
Bull coins (DNH) are paving the way for the bull market and the autonomous development of purely decentralized communities!  
Solve all centralized artificial pain points!  
Solve the major problems of concentrated token chips, selling pressure, fear of holding, and fear of belief!  
Empower DNH to enter the contract through BNB, and mine it with everyone’s market value!  
The output method is based on the proportion of contribution value. 
All participants are project parties and are also market value!  
Execution through on-chain contracts!  
The greater the contribution value, the more DNH you will get!  
Everyone is equal, and the market value of everyone’s contract can truly create a myth of ten thousand times!-Short Project 

contractAddress: 0x29D00fA820f7a3c6063f7e37cd580b479A333333
*/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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

contract MidWallet{
    address public wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public usdt = 0x55d398326f99059fF775485246999027B3197955;
    constructor(address to){
        IERC20(wbnb).approve(to, ~uint256(0));
        IERC20(usdt).approve(to, ~uint256(0));
    }
}

contract DNH is IERC20, Ownable{
    string private _name = "DNH";
    string private _symbol = "DNH";
    uint8 private _decimals = 18;
    uint256 private _totalsupply =100000000 * 10 ** 18;
    uint256 public constant MAX = ~uint256(0);  
    uint256 public dayBlock = 28800;
    uint256 public perDayReward = 15;
    uint256 public maxD = 50;

    uint256[] public shareRateList =[10,10,10,5,5,5,5,5,5,5];

    uint256 public totalUser;   
    uint256 public totalInvestTime; 
    uint256 public totalValue;  
    uint256 public preBuyAmount;
    uint256 public nftRewardAmount;
    uint256 public _tokenId = 277617;
    uint256 public lpBNBAmounts;
    uint128 public lpAmounts;
    uint256 public sosAmounts;

    mapping(address => uint256) private _balances;     
    mapping(address => mapping(address => uint256)) private _allowances;    

    address public dev = 0xb218cF2B8eE8Bd2d6Fa031497fD5ecFAa394e3BB;
    address public nftRewards = 0xF0145CA3e6c34C58af78D3D0a7166Fe77eF5720D;
    address public nodeRewards = 0xD2A7d87cA859578D0b7Ed4c0DCa199cb2507Ae8D;
    address public factory = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address public router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address public wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;          
    address public usdt = 0x55d398326f99059fF775485246999027B3197955;          
    address public sysAddr = 0x8B2657cef7d71d4c68D677Ee9138a24F02125c96;         
    address public firstAddr = 0x6B116b862c02c7542169B78227509E43564f0236;  
    address public bnbPair;
    address public usdtPair;
    address public wallet = 0x36696169C63e42cd08ce11f5deeBbCeBae652050;         
    address public deadAddr = 0x000000000000000000000000000000000000dEaD;       
    address public V3Manage = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;      
    MidWallet public midWallet;       
    address public lqmanage = 0x366B2c08211969A8b38CA9f53913987B3880Aead;    
    address public buyDNBSaddr =0x678Ed5A5A0103bE257430031EBfd7e2DA52B09E9; 
    address public dnbs = 0xF68e7c0A801df12bDd4b4a6395af61b318999999;
    address public sosContract = 0x6B7aA0625821FeFCFFbe50beB824f436Ce888888; 
    address public v3_position_calc = 0x417Bb7be0BB80c3e9Ca3aAc6d1A5443f38666666;
    bool public investStatus; 


    mapping(address=>address) public userTop;       
    mapping(address => uint256) public userLastActionBlock;     
    mapping(address => uint256) public userInvestBNBAmount;     
    mapping(address => uint256) public userShareLevel;          
    mapping(address => uint256) public userPrebuyBNBAmount;     
    mapping(address => uint256) public userClaimRewardBNBValue;   
    mapping(address => uint256) public userClaimRewardDNHAmount;    
    mapping(address => uint256) public userInviteAddr;             
    mapping(address => uint256) public userTotalShareAddr;          
    mapping(address => uint256) public teamTotalAddr;               
    mapping(address => uint256) public teamTotalInvestValue;      
    mapping(address=>mapping(address=>bool)) public bindState;



    mapping(address => uint256) public pendingShareRewards;         
    mapping(address => uint256) public claimdShareRewards;          
    mapping(address => uint256) public pendingTeamRewards;          
    mapping(address => uint256) public claimdTeamRewards;           



    event Invest(address indexed from, uint256 indexed times, uint256 value); 
    
    constructor (
    ){
        
        _balances[dev] = _totalsupply;
        emit Transfer(address(0), dev, _totalsupply);

        (address token0, address token1) = sortTokens(usdt, address(this));
        usdtPair = address(uint160(uint(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token0, token1)),
            hex'00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5'
        )))));

        (address token3, address token4) = sortTokens(wbnb, address(this));
        bnbPair = address(uint160(uint(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token3, token4)),
            hex'00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5'
        )))));

        midWallet = new MidWallet(address(this));

        userTop[dev] = address(1);
        userTop[firstAddr] =dev;

    }

    modifier onlySOSContract{
        require(msg.sender == sosContract,'onlySOSContract');
        _;
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
        require(userInvestBNBAmount[sender] ==0,"Wait End !");  
        require(fromBNBAmount >= 1 ether,"Min Invest Value");   

        address top = userTop[sender];      

        if(top != address(0)){
            userTotalShareAddr[top] ++;
            if(userShareLevel[top] <10){
                uint256 _shareLevel = userTotalShareAddr[top];
                if(_shareLevel>10){
                    _shareLevel =10;
                }
                userShareLevel[top] = _shareLevel;
            }
            for(uint256 i=0;i<maxD;i++){
                if(top !=address(0) && top !=address(1)){
                    teamTotalAddr[top] ++;  
                    teamTotalInvestValue[top] += fromBNBAmount; 
                    top = userTop[top];
                }
            }
        }

        userInvestBNBAmount[sender] = fromBNBAmount;    
        userPrebuyBNBAmount[sender] += (fromBNBAmount*78/100); 
        uint256 firstBuyValue = fromBNBAmount*2/100;        
        internalBuy(firstBuyValue); 
        userLastActionBlock[sender] = block.number; 
        
        preBuyAmount +=(fromBNBAmount*78/100);
        nftRewardAmount +=(fromBNBAmount*10/100);
        payable(nftRewards).transfer(fromBNBAmount*10/100); 
        payable(nodeRewards).transfer(fromBNBAmount*4/100); 

        
        address topA;
        address topB;
        address topC;
        topA = userTop[sender];
        if(topA !=address(0) && userShareLevel[topA] >=1){
            
            uint256 topAInvestAmount = userInvestBNBAmount[topA];   
            if(topAInvestAmount>0){
                uint256 tpARewards = fromBNBAmount * 3/100; 
                if((userClaimRewardBNBValue[topA] + tpARewards) >= (topAInvestAmount *150/100)){
                    
                    tpARewards = (topAInvestAmount *150/100) - userClaimRewardBNBValue[topA];       
                }

                if(tpARewards>0){
                    payable(topA).transfer(tpARewards);
                    userClaimRewardBNBValue[topA] += tpARewards;        
                }

                if(userClaimRewardBNBValue[topA]>=(topAInvestAmount *150/100)){ 

                    sosAmounts+=userPrebuyBNBAmount[topA];  
                    userInvestBNBAmount[topA] =0;
                    userLastActionBlock[topA] = 0;
                    userPrebuyBNBAmount[topA] =0;
                    userClaimRewardBNBValue[topA]=0;
                    pendingShareRewards[topA]=0;
                    claimdShareRewards[topA]=0;
                    pendingTeamRewards[topA]=0;
                    claimdTeamRewards[topA]=0;
                    totalUser--;
                }
            }else{
                payable(sysAddr).transfer(fromBNBAmount * 3/100);
            }
            
            topB = userTop[topA];
            if(topB != address(0) && userShareLevel[topB] >=2){
                
                uint256 topBInvestAmount = userInvestBNBAmount[topB];   
                if(topBInvestAmount>0){
                    uint256 tpBRewards = fromBNBAmount * 2/100; 
                    if((userClaimRewardBNBValue[topB] + tpBRewards) >= (topBInvestAmount *150/100)){
                        
                        tpBRewards = (topBInvestAmount *150/100) - userClaimRewardBNBValue[topB];       
                    }

                    if(tpBRewards>0){
                        payable(topB).transfer(tpBRewards);
                        userClaimRewardBNBValue[topB] += tpBRewards;        
                    }

                    if(userClaimRewardBNBValue[topB]>=(topBInvestAmount *150/100)){ 

                        sosAmounts+=userPrebuyBNBAmount[topB];  
                        userInvestBNBAmount[topB] =0;
                        userLastActionBlock[topB] = 0;
                        userPrebuyBNBAmount[topB] =0;
                        userClaimRewardBNBValue[topB]=0;
                        pendingShareRewards[topB]=0;
                        claimdShareRewards[topB]=0;
                        pendingTeamRewards[topB]=0;
                        claimdTeamRewards[topB]=0;
                        totalUser--;
                    }
                }else{
                    payable(sysAddr).transfer(fromBNBAmount * 2/100);
                }

                topC = userTop[topB];
                if(topC != address(0) && userShareLevel[topC] >=3){
                    
                    uint256 topCInvestAmount = userInvestBNBAmount[topC];   
                    if(topCInvestAmount>0){
                        uint256 tpCRewards = fromBNBAmount * 1/100; 
                        if((userClaimRewardBNBValue[topC] + tpCRewards) >= (topCInvestAmount *150/100)){
                            
                            tpCRewards = (topCInvestAmount *150/100) - userClaimRewardBNBValue[topC];       
                        }

                        if(tpCRewards>0){
                            payable(topC).transfer(tpCRewards);
                            userClaimRewardBNBValue[topC] += tpCRewards;        
                        }

                        if(userClaimRewardBNBValue[topC]>=(topCInvestAmount *150/100)){ 

                            sosAmounts+=userPrebuyBNBAmount[topC];  
                            userInvestBNBAmount[topC] =0;
                            userLastActionBlock[topC] = 0;
                            userPrebuyBNBAmount[topC] =0;
                            userClaimRewardBNBValue[topC]=0;
                            pendingShareRewards[topC]=0;
                            claimdShareRewards[topC]=0;
                            pendingTeamRewards[topC]=0;
                            claimdTeamRewards[topC]=0;
                            totalUser--;
                        }
                    }else{
                        payable(sysAddr).transfer(fromBNBAmount * 1/100);
                    }
                }else{
                    
                    payable(sysAddr).transfer(fromBNBAmount * 1/100);
                }
            }else{
                
                payable(sysAddr).transfer(fromBNBAmount * 3/100);
            }
        }else{
            
            payable(sysAddr).transfer(fromBNBAmount * 6/100);

        }


        totalUser++;
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

        if(_balances[address(this)] > 1e14){
            uint256 endBal = _balances[address(this)] -1e14;
            _balances[address(this)] = endBal;
            _balances[sender] = _balances[sender] + 1e14;
            emit Transfer(address(this), sender, 1e14);
        }
        emit Invest(sender,block.number,fromBNBAmount);
        return;
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

    
    bool inswap;    
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

        if(inswap || (to == dev && !investStatus)){ 
            _balances[to] +=amount;
            emit Transfer(from, to, amount);
            return;
        }

        if(from == bnbPair || from == usdtPair){    
            if(from == bnbPair){
                revert('Buy Forbid');
            }else{
                if(to == bnbPair){
                    revert('Bot Swap');
                }
                uint256 burnAmount = amount * 2 / 100;
                uint256 transBuyAmount = amount - burnAmount;
                _balances[deadAddr] +=burnAmount;
                emit Transfer(from, deadAddr, burnAmount);
                _balances[to] +=transBuyAmount;
                emit Transfer(from, to, transBuyAmount); 
                return;
            }
        }

        if(to == address(this)){    
            address sender = msg.sender;
            require(sender == from,"Bot");
            require(sender == tx.origin,'BOT');
            _balances[address(this)] +=amount;
            emit Transfer(from, to, amount);   

            uint256 userInvestAmount = userInvestBNBAmount[sender];
            if(userInvestAmount == 0 || userLastActionBlock[sender]==0 ||  (userLastActionBlock[sender] + dayBlock ) > block.number){
                return;
            }


            uint256 userInvestDay = (block.number - userLastActionBlock[sender]) / dayBlock;
            uint256 staticPending = ((userInvestAmount * userInvestDay) * perDayReward)/1000;
            if(staticPending>0){
                address top = userTop[sender]; 
                if(top == address(0)){
                    top = sysAddr;
                }

                for(uint8 i=0;i<shareRateList.length;i++){
                    if(top !=address(0)){
                        if((userShareLevel[top] >= (i+1)) && (userInvestBNBAmount[top]>0)){
                            uint256 shareRewars = (staticPending * shareRateList[i]) / 100;
                            pendingShareRewards[top] += shareRewars;
                        }
                        top = userTop[top];
                    }
                }

                uint256 maxTeamRate = 35;   
                uint256 spendRate=0;    
                address top_team = userTop[sender]; 
                if(top_team == address(0)){
                    top_team = sysAddr;
                }
                for(uint256 j=0;j<maxD;j++){ 
                    if(top_team !=address(0)){
                        if(teamTotalInvestValue[top_team] >= 70000*10**18 && maxTeamRate>spendRate && userInvestBNBAmount[top_team]>0){
                            pendingTeamRewards[top_team] += ((staticPending * (maxTeamRate - spendRate)) / 100);
                            spendRate = 35;
                        }
                        if(teamTotalInvestValue[top_team] >= 30000*10**18 && teamTotalInvestValue[top_team] < 70000*10**18 &&  spendRate<30 && userInvestBNBAmount[top_team]>0){
                            pendingTeamRewards[top_team] += ((staticPending * (30 - spendRate)) / 100);
                            spendRate = 30;
                        }
                        if(teamTotalInvestValue[top_team] >= 10000*10**18 && teamTotalInvestValue[top_team] < 30000*10**18 &&  spendRate<25 && userInvestBNBAmount[top_team]>0){
                            pendingTeamRewards[top_team] += ((staticPending * (25 - spendRate)) / 100);
                            spendRate = 25;
                        }
                        if(teamTotalInvestValue[top_team] >= 3000*10**18 && teamTotalInvestValue[top_team] < 10000*10**18 &&  spendRate<20 && userInvestBNBAmount[top_team]>0){
                            pendingTeamRewards[top_team] += ((staticPending * (20 - spendRate)) / 100);
                            spendRate = 20;
                        }
                        if(teamTotalInvestValue[top_team] >= 1000*10**18 && teamTotalInvestValue[top_team] < 3000*10**18 &&  spendRate<15 && userInvestBNBAmount[top_team]>0){
                            pendingTeamRewards[top_team] += ((staticPending * (15 - spendRate)) / 100);
                            spendRate = 15;
                        }
                        if(teamTotalInvestValue[top_team] >= 300*10**18 && teamTotalInvestValue[top_team] < 1000*10**18 &&  spendRate<10 && userInvestBNBAmount[top_team]>0){
                            pendingTeamRewards[top_team] += ((staticPending * (10 - spendRate)) / 100);
                            spendRate = 10;
                        }
                        if(teamTotalInvestValue[top_team] >= 100*10**18 && teamTotalInvestValue[top_team] < 300*10**18 &&  spendRate<5 && userInvestBNBAmount[top_team]>0){
                            pendingTeamRewards[top_team] += ((staticPending * (5 - spendRate)) / 100);
                            spendRate = 5;
                        }
                        top_team = userTop[top_team];
                    }
                }
            }

            uint256 myShareRewards = pendingShareRewards[sender];
            uint256 myTeamRewards = pendingTeamRewards[sender];
            uint256 myTotalRewards = staticPending + myShareRewards + myTeamRewards;

            if(userPrebuyBNBAmount[sender] >0 && (userPrebuyBNBAmount[sender] >= (userInvestAmount/50)) && (userInvestDay >= 1)){
                uint256 buyRate =userPrebuyBNBAmount[sender] * 50 /userInvestAmount;     
                if(buyRate > userInvestDay){ 
                    buyRate = userInvestDay;
                }
                uint256 needBuyValues = (userInvestAmount * buyRate) / 50;      
                claimRewardsBuy(needBuyValues);
                
                if(userPrebuyBNBAmount[sender] >= needBuyValues){
                    uint256 endPre = userPrebuyBNBAmount[sender] - needBuyValues;
                    userPrebuyBNBAmount[sender] = endPre;
                }else{
                    userPrebuyBNBAmount[sender]=0;
                }
            }

            claimdShareRewards[sender] += myShareRewards;
            claimdTeamRewards[sender]+=myTeamRewards;
            pendingShareRewards[sender]=0;
            pendingTeamRewards[sender]=0;
            
            if((userClaimRewardBNBValue[sender] + myTotalRewards) >= (userInvestAmount *15/10)){
                
                myTotalRewards = (userInvestAmount *15/10) - userClaimRewardBNBValue[sender];   
            }

            if(myTotalRewards>0){
                uint256 preDNHAmount = _getAmountsOut(myTotalRewards);
                require(_balances[address(this)] >= preDNHAmount,"Low DNH");
                uint256 endSendDnhAmount = _balances[address(this)] - preDNHAmount;
                _balances[address(this)] = endSendDnhAmount;
                _balances[sender] += preDNHAmount;
                emit Transfer(address(this), sender, preDNHAmount);
                userClaimRewardBNBValue[sender] += myTotalRewards;
                userLastActionBlock[sender] = block.number;

            }

            if(userClaimRewardBNBValue[sender]>=(userInvestAmount *15/10)){
                if(userPrebuyBNBAmount[sender]>0){
                    sosAmounts +=userPrebuyBNBAmount[sender];
                }
                userInvestBNBAmount[sender] =0;
                userLastActionBlock[sender] = 0;
                userPrebuyBNBAmount[sender] =0;
                userClaimRewardBNBValue[sender]=0;
                pendingShareRewards[sender]=0;
                claimdShareRewards[sender]=0;
                pendingTeamRewards[sender]=0;
                claimdTeamRewards[sender]=0;
                totalUser--;
            }
            return;
        }

        uint256 sellFeeAmount;
        uint256 buyDNBSAmount;
        if(to == bnbPair || to ==usdtPair){ 
            if(from != dev){
                sellFeeAmount = amount * 20 /100;
                buyDNBSAmount = amount * 10 /100;
            }
        }

        if(sellFeeAmount>0){
            _balances[address(this)] +=sellFeeAmount;
            emit Transfer(from, address(this), sellFeeAmount); 
            swapAndliq(to, sellFeeAmount);
        }

        if(buyDNBSAmount>0){
            _balances[address(this)] +=buyDNBSAmount;
            emit Transfer(from, address(this), buyDNBSAmount); 
            swapAndBuyDNB(to,buyDNBSAmount);
        }
        uint256 feeAll =sellFeeAmount+ buyDNBSAmount;

        uint256 transAmount = amount - feeAll;
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

        ISwapRouter(router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: bnbAmount}(0, path, wallet, block.timestamp+1000);
        uint256 bal = balanceOf(wallet);
        _balances[wallet] = 0;
        _balances[address(this)] +=bal;
        emit Transfer(wallet, address(this), bal);
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
        ISwapRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(amount1,0,path,wallet,block.timestamp+1000);
        uint256 bal = balanceOf(wallet);
        _balances[wallet] = 0;
        _balances[address(this)] +=bal;
        emit Transfer(wallet, address(this), bal);
        inswap=false;
    }

    function swapAndliq(address pair, uint256 tokenAmount) private{
        require(!inswap,"inSwap");
        inswap =true;
        uint256 swapAmount = tokenAmount/2;
        IERC20(address(this)).approve(router, swapAmount);
        address[] memory path = new address[](2);

        if(pair == bnbPair){
            path[0] = address(this);
            path[1] = wbnb;
            ISwapRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(swapAmount,0,path,address(midWallet),block.timestamp+1000);
            uint256 addliqUsdt = IERC20(wbnb).balanceOf(address(midWallet));
            IERC20(wbnb).transferFrom(address(midWallet), address(this), addliqUsdt);
            uint256 addliqDnbs = tokenAmount - swapAmount;
            IERC20(wbnb).transfer(pair, addliqUsdt);
            IERC20(address(this)).transfer(pair,addliqDnbs);
            ISwapPair(pair).mint(lqmanage);
            inswap =false;
        }else{
            path[0] = address(this);
            path[1] = usdt;
            ISwapRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(swapAmount,0,path,address(midWallet),block.timestamp+1000);
            uint256 addliqUsdt = IERC20(usdt).balanceOf(address(midWallet));
            IERC20(usdt).transferFrom(address(midWallet), address(this), addliqUsdt);
            uint256 addliqDnbs = tokenAmount - swapAmount;
            IERC20(usdt).transfer(pair, addliqUsdt);
            IERC20(address(this)).transfer(pair,addliqDnbs);
            ISwapPair(pair).mint(lqmanage);
            inswap =false;
        }
        inswap =false;
    }

    function swapAndBuyDNB(address pair,uint256 swapAmount) private{
        require(!inswap,"inSwap");
        inswap =true;
        IERC20(address(this)).approve(router, swapAmount);
        if(pair == bnbPair){
            address[] memory path = new address[](4);
            path[0] = address(this);
            path[1] = wbnb;
            path[2] = usdt;
            path[3] = dnbs;
            uint256 startDnbBal = IERC20(dnbs).balanceOf(address(this));
            ISwapRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(swapAmount,0,path,address(this),block.timestamp+1000);
            uint256 endDnbBal = IERC20(dnbs).balanceOf(address(this));
            if(endDnbBal>startDnbBal){
                uint256 dnbAmount = endDnbBal - startDnbBal;
                uint256 burnAmount = dnbAmount/2;
                uint256 rewardAmount = dnbAmount - burnAmount;
                IERC20(dnbs).transfer(address(0), burnAmount);
                IERC20(dnbs).transfer(buyDNBSaddr, rewardAmount);
            }
            inswap =false;

        }else{
            address[] memory path = new address[](3);
            path[0] = address(this);
            path[1] = usdt;
            path[2] = dnbs;
            uint256 startDnbBal = IERC20(dnbs).balanceOf(address(this));
            ISwapRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(swapAmount,0,path,address(this),block.timestamp+1000);
            uint256 endDnbBal = IERC20(dnbs).balanceOf(address(this));
            if(endDnbBal>startDnbBal){
                uint256 dnbAmount = endDnbBal - startDnbBal;
                uint256 burnAmount = dnbAmount/2;
                uint256 rewardAmount = dnbAmount - burnAmount;
                IERC20(dnbs).transfer(address(0), burnAmount);
                IERC20(dnbs).transfer(buyDNBSaddr, rewardAmount);
            }
            inswap =false;
        }
        inswap =false;
    }

    function _getAmountsOut(uint256 bnbAmount) private view returns(uint256){
        address[] memory path = new address[](2);
        path[0] = wbnb;
        path[1] = address(this);
        uint256[] memory amounts = ISwapRouter(router).getAmountsOut(bnbAmount, path);
        return amounts[1];
    }
    

    function sosBuy(uint256 bnbAmount) public onlySOSContract{
        require(sosAmounts>=bnbAmount,'Low sosAmounts');
        claimRewardsBuy(bnbAmount);
        uint256 endAmount = sosAmounts - bnbAmount;
        sosAmounts = endAmount;
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'PancakeLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'PancakeLibrary: ZERO_ADDRESS');
    }


    function openProject()public onlyOwner{
        require(!investStatus,'Start');
        investStatus = true;
    }
}
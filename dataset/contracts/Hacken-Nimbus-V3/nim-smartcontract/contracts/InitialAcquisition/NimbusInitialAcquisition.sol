pragma solidity =0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Ownable {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed from, address indexed to);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Ownable: Caller is not the owner");
        _;
    }

    function transferOwnership(address transferOwner) external onlyOwner {
        require(transferOwner != newOwner);
        newOwner = transferOwner;
    }

    function acceptOwnership() virtual external {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

abstract contract Pausable is Ownable {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor () {
        _paused = false;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }


    function pause() external onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

interface INBU is IERC20 {
    function give(address recipient, uint256 amount, uint vesterId) external;
}

interface INimbusReferralProgram {
    function userSponsorByAddress(address user)  external view returns (uint);
    function userIdByAddress(address user) external view returns (uint);
    function userAddressById(uint id) external view returns (address);
    function userSponsorAddressByAddress(address user) external view returns (address);
}

interface INimbusStakingPool {
    function stakeFor(uint amount, address user) external;
    function balanceOf(address account) external view returns (uint256);
    function stakingToken() external view returns (IERC20);
}

interface INBU_WETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface INimbusRouter {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}



contract NimbusInitialAcquisition is Ownable, Pausable {
    INBU public immutable NBU;
    address public immutable NBU_WETH;
    INimbusReferralProgram public referralProgram;
    INimbusStakingPool[] public stakingPools;   //staking pools for checking sponsor balances
    INimbusStakingPool public stakePool;        //staking pool for staking purchased assets
    address public recipient;                      
   
    INimbusRouter public swapRouter;                
    mapping (address => bool) public allowedTokens;
    address public swapToken;                       
    uint public swapTokenAmountForBonusThreshold;  
    
    uint public sponsorBonus;
    mapping(address => uint) public unclaimedBonusBases;

    event BuyNbuForToken(address indexed token, uint tokenAmount, uint nbuAmount, address indexed nbuRecipient);
    event BuyNbuForEth(uint ethAmount, uint nbuAmount, address indexed nbuRecipient);
    event ProcessSponsorBonus(address indexed sponsor, address indexed user, uint bonusAmount);
    event AddUnclaimedSponsorBonus(address indexed user, uint nbuAmount);

    event UpdateTokenNbuExchangeRate(address indexed token, uint newRate);
    event UpdateEthNbuExchangeRate(uint newRate);
    event Rescue(address indexed to, uint amount);
    event RescueToken(address indexed token, address indexed to, uint amount); 

    constructor (address nbu, address router, address nbuWeth, address pool) {
        NBU = INBU(nbu);
        NBU_WETH = nbuWeth;
        sponsorBonus = 10;
        swapRouter = INimbusRouter(router);
        recipient = address(this);
        stakePool = INimbusStakingPool(pool);
    }

    function availableInitialSupply() external view returns (uint) {
        return NBU.balanceOf(address(this));
    }

    function getNbuAmountForToken(address token, uint tokenAmount) public view returns (uint) { 
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(NBU);
        return swapRouter.getAmountsOut(tokenAmount, path)[1];
    }

    function getNbuAmountForEth(uint ethAmount) public view returns (uint) { 
        return getNbuAmountForToken(NBU_WETH, ethAmount); 
    }

    function getTokenAmountForNbu(address token, uint nbuAmount) public view returns (uint) { 
        address[] memory path = new address[](2);
        path[0] = address(NBU);
        path[1] = token;
        return swapRouter.getAmountsOut(nbuAmount, path)[1];
    }

    function getEthAmountForNbu(uint nbuAmount) public view returns (uint) { 
        return getTokenAmountForNbu(NBU_WETH, nbuAmount);
    }

    function currentBalance(address token) external view returns (uint) { 
        return INBU(token).balanceOf(address(this));
    }


    


    function _buyNbu(address token, uint tokenAmount, uint nbuAmount, address nbuRecipient) private {
        stakePool.stakeFor(nbuAmount, nbuRecipient);
        emit BuyNbuForToken(token, tokenAmount, nbuAmount, nbuRecipient);
        _processSponsor(nbuAmount);
    }

    function _processSponsor(uint nbuAmount) private {
        address sponsorAddress = _getUserSponsorAddress();
        if (sponsorAddress != address(0)) { 
            uint minNbuAmountForBonus = getNbuAmountForToken(swapToken, swapTokenAmountForBonusThreshold);
            if (nbuAmount > minNbuAmountForBonus) {
                uint sponsorAmount = NBU.balanceOf(sponsorAddress);
                for (uint i; i < stakingPools.length; i++) {
                    if (sponsorAmount > minNbuAmountForBonus) break;
                    sponsorAmount += stakingPools[i].balanceOf(sponsorAddress);
                }
                
                if (sponsorAmount > minNbuAmountForBonus) {
                    uint bonusBase = nbuAmount + unclaimedBonusBases[msg.sender];
                    uint sponsorBonusAmount = bonusBase * sponsorBonus / 100;
                    NBU.give(sponsorAddress, sponsorBonusAmount, 3);
                    unclaimedBonusBases[msg.sender] = 0;
                    emit ProcessSponsorBonus(sponsorAddress, msg.sender, sponsorBonusAmount);
                } else {
                    unclaimedBonusBases[msg.sender] += nbuAmount;
                    emit AddUnclaimedSponsorBonus(msg.sender, nbuAmount);
                }
            } else {
                unclaimedBonusBases[msg.sender] += nbuAmount;
                emit AddUnclaimedSponsorBonus(msg.sender, nbuAmount);
            }
        } else {
            unclaimedBonusBases[msg.sender] += nbuAmount;
            emit AddUnclaimedSponsorBonus(msg.sender, nbuAmount);
        }
    }

    function _getUserSponsorAddress() private view returns (address) {
        if (address(referralProgram) == address(0)) {
            return address(0);
        } else {
            return referralProgram.userSponsorAddressByAddress(msg.sender);
        } 
    }
    
    function buyExactNbuForTokens(address token, uint nbuAmount, address nbuRecipient) external whenNotPaused {
        require(allowedTokens[token], "NimbusInitialAcquisition: Not allowed token");
        uint tokenAmount = getTokenAmountForNbu(token, nbuAmount);
        TransferHelper.safeTransferFrom(token, msg.sender, recipient, tokenAmount);
        _buyNbu(token, tokenAmount, nbuAmount, nbuRecipient);
    }

    function buyNbuForExactTokens(address token, uint tokenAmount, address nbuRecipient) external whenNotPaused {
        require(allowedTokens[token], "NimbusInitialAcquisition: Not allowed token");
        uint nbuAmount = getNbuAmountForToken(token, tokenAmount);
        TransferHelper.safeTransferFrom(token, msg.sender, recipient, tokenAmount);
        _buyNbu(token, tokenAmount, nbuAmount, nbuRecipient);
    }

    function buyNbuForExactEth(address nbuRecipient) payable external whenNotPaused {
        require(allowedTokens[NBU_WETH], "NimbusInitialAcquisition: Not allowed purchase for ETH");
        uint nbuAmount = getNbuAmountForEth(msg.value);
        INBU_WETH(NBU_WETH).deposit{value: msg.value}();
        _buyNbu(NBU_WETH, msg.value, nbuAmount, nbuRecipient);
    }

    function buyExactNbuForEth(uint nbuAmount, address nbuRecipient) payable external whenNotPaused {
        require(allowedTokens[NBU_WETH], "NimbusInitialAcquisition: Not allowed purchase for ETH");
        uint nbuAmountMax = getNbuAmountForEth(msg.value);
        require(nbuAmountMax >= nbuAmount, "NimbusInitialAcquisition: Not enough ETH");
        uint ethAmount = nbuAmountMax == nbuAmount ? msg.value : getEthAmountForNbu(nbuAmount);
        INBU_WETH(NBU_WETH).deposit{value: ethAmount}();
        _buyNbu(NBU_WETH, ethAmount, nbuAmount, nbuRecipient);
        // refund dust eth, if any
        if (nbuAmountMax > nbuAmount) TransferHelper.safeTransferETH(msg.sender, msg.value - ethAmount);
    }


    function claimSponsorBonusesBatch(address[] memory users) external { 
        for (uint i; i < users.length; i++) {
            claimSponsorBonuses(users[i]);
        }
    }

    function claimSponsorBonuses(address user) public {
        require(unclaimedBonusBases[user] > 0, "NimbusInitialAcquisition: No unclaimed bonuses");
        uint userSponsor = referralProgram.userSponsorByAddress(user);
        require(userSponsor == referralProgram.userIdByAddress(msg.sender) && userSponsor != 0, "NimbusInitialAcquisition: Not user sponsor");
        
        uint minNbuAmountForBonus = getNbuAmountForToken(swapToken, swapTokenAmountForBonusThreshold);
        uint bonusBase = unclaimedBonusBases[user];
        require (bonusBase >= minNbuAmountForBonus, "NimbusInitialAcquisition: Bonus threshold not met");

        uint sponsorAmount = NBU.balanceOf(msg.sender);
        for (uint i; i < stakingPools.length; i++) {
            if (sponsorAmount > minNbuAmountForBonus) break;
            sponsorAmount += stakingPools[i].balanceOf(msg.sender);
        }
        
        require (sponsorAmount > minNbuAmountForBonus, "NimbusInitialAcquisition: Sponsor balance threshold for bonus not met");
        uint sponsorBonusAmount = bonusBase * sponsorBonus / 100;
        NBU.give(msg.sender, sponsorBonusAmount, 3);
        unclaimedBonusBases[user] = 0;
        emit ProcessSponsorBonus(msg.sender, user, sponsorBonusAmount);
    }
    


    //Admin functions
    function rescue(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "NimbusInitialAcquisition: Can't be zero address");
        require(amount > 0, "NimbusInitialAcquisition: Should be greater than 0");
        TransferHelper.safeTransferETH(to, amount);
        emit Rescue(to, amount);
    }

    function rescue(address to, address token, uint256 amount) external onlyOwner {
        require(to != address(0), "NimbusInitialAcquisition: Can't be zero address");
        require(amount > 0, "NimbusInitialAcquisition: Should be greater than 0");
        TransferHelper.safeTransfer(token, to, amount);
        emit RescueToken(token, to, amount);
    }

    function updateAllowedTokens(address token, bool isAllowed) external onlyOwner {
        require (token != address(0), "NimbusInitialAcquisition: Wrong addresses");
        allowedTokens[token] = isAllowed;
    }
    
    function updateRecipient(address recipientAddress) external onlyOwner {
        require(recipientAddress != address(0), "NimbusInitialAcquisition: Address is zero");
        recipient = recipientAddress;
    } 

    function updateSponsorBonus(uint bonus) external onlyOwner {
        sponsorBonus = bonus;
    }

    function updateReferralProgramContract(address newReferralProgramContract) external onlyOwner {
        require(newReferralProgramContract != address(0), "NimbusInitialAcquisition: Address is zero");
        referralProgram = INimbusReferralProgram(newReferralProgramContract);
    }

    function updateStakePool(address newStakingPool) external onlyOwner {
        require(newStakingPool != address(0), "NimbusInitialAcquisition: Address is zero");
        if (address(stakePool) != address(0)) NBU.approve(address(stakePool), 0);
        stakePool = INimbusStakingPool(newStakingPool);
        NBU.approve(newStakingPool, type(uint256).max);
    }

    function updateStakingPoolAdd(address newStakingPool) external onlyOwner {
        INimbusStakingPool pool = INimbusStakingPool(newStakingPool);
        require (pool.stakingToken() == NBU, "NimbusInitialAcquisition: Wrong pool staking tokens");

        for (uint i; i < stakingPools.length; i++) {
            require (address(stakingPools[i]) != newStakingPool, "NimbusInitialAcquisition: Pool exists");
        }
        stakingPools.push(pool);
    }

    function updateStakingPoolRemove(uint poolIndex) external onlyOwner {
        stakingPools[poolIndex] = stakingPools[stakingPools.length - 1];
        stakingPools.pop();
    }

    function updateSwapRouter(address newSwapRouter) external onlyOwner {
        require(newSwapRouter != address(0), "NimbusInitialAcquisition: Address is zero");
        swapRouter = INimbusRouter(newSwapRouter);
    }

    function updateSwapToken(address newSwapToken) external onlyOwner {
        require(newSwapToken != address(0), "NimbusInitialAcquisition: Address is zero");
        swapToken = newSwapToken;
    }

    function updateSwapTokenAmountForBonusThreshold(uint threshold) external onlyOwner {
        swapTokenAmountForBonusThreshold = threshold;
    }
}

library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}
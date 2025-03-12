// SPDX-License-Identifier: MIT

// pragma solidity 0.7.6;

import "./RUSD-additional/CastU256U128.sol";
import "./RUSD-additional/CastU256U32.sol";
import "./RUSD-additional/SafeMathInt.sol";
import "./RUSD-additional/SafeMath.sol";
import "./RUSD-additional/Initializable.sol";
import "./RUSD-additional/IERC20.sol";
import "./RUSD-additional/Ownable.sol";
import "./RUSD-additional/ERC20Detailed.sol";
import "./RUSD-additional/IProviderPair.sol";

interface IRouter {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function getAmountsOut(uint256 amountIn, address[] memory path)
        external
        view
        returns (uint256[] memory amounts);

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IRUSDRewards {
    function _updateRewardsPerToken() external;

    function _updateUserRewards(address user) external;
}

contract RUSDFraction is ERC20Detailed, Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using CastU256U32 for uint256;
    using CastU256U128 for uint256;

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event LogMonetaryPolicyUpdated(address monetaryPolicy);
    event LogDeveloperAddress(address developer);
    event LogLiquidityAddress(address liquidityPool);
    event LogDeveloperFee(
        uint256 sellDeveloperPercent,
        uint256 buyDeveloperPercent
    );
    event LogLiquidityFee(uint256 sellLiquidityFee, uint256 buyLiquidityFee);

    modifier validRecipient(address to) {
        require(to != address(0x0));
        require(to != address(this));
        _;
    }

    struct Fees {
        uint256 devSellFee;
        uint256 devBuyFee;
        uint256 rewardPoolSellFee;
        uint256 rewardPoolBuyFee;
        uint256 reflectoBBSellFee;
        uint256 reflectoBBBuyFee;
        uint256 liquiditySellFee;
        uint256 liquidityBuyFee;
    }
    mapping(address => Fees) public usersFees;
    mapping(address => bool) public isCustomFee;
    mapping(address => bool) public isExcludedFromAllFees;

    mapping(address => uint256) public timeOfSell;
    mapping(address => uint256) public amountOfSell;
    uint256 public sellLimit;

    uint256 private constant DECIMALS = 9;
    uint256 private constant MAX_UINT256 = type(uint256).max;
    uint256 private constant INITIAL_FRACTIONS_SUPPLY =
        50 * 10**6 * 10**DECIMALS; // 50 million

    // TOTAL_FRAC is a multiple of INITIAL_FRACTIONS_SUPPLY so that _fracsPerRUSD is an integer.
    // Use the highest value that fits in a uint256 for max granularity.
    uint256 private constant TOTAL_FRAC =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRACTIONS_SUPPLY);

    // MAX_SUPPLY = maximum integer < (sqrt(4*TOTAL_FRAC + 1) - 1) / 2
    uint256 private constant MAX_SUPPLY = type(uint128).max; // (2^128) - 1

    address public monetaryPolicy;
    IProviderPair[] public providerPairs;
    IRUSDRewards public rusdRewardContract;
    address public developer;
    address public liquidityPool;
    uint256 public sellDeveloperPercent;
    uint256 public buyDeveloperPercent;
    uint256 public sellLiquidityFee;
    uint256 public buyLiquidityFee;
    uint256 public buyBackPool;
    uint256 public buyBackContract;
    uint256 public sellBackPool;
    uint256 public sellBackContract;
    address public reflectoAdd;
    address public poolAddress;
    uint256 private _totalSupply;
    uint256 private _fracsPerRUSD;
    mapping(address => uint256) public nonces;

    bytes32 public constant PERMIT_TYPEHASH_META =
        0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;

    mapping(address => uint256) private _fracBalances;

    // This is denominated in fractions, because the fracs-fractions conversion might change before
    // it's fully paid.
    mapping(address => mapping(address => uint256)) private _allowedFractions;

    // EIP-2612: permit – 712-signed approvals
    // https://eips.ethereum.org/EIPS/eip-2612
    string public constant EIP712_REVISION = "1";
    bytes32 public constant EIP712_DOMAIN =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    function excludeFromAllFees(address holder_, bool isExcluded)
        external
        onlyOwner
    {
        isExcludedFromAllFees[holder_] = isExcluded;
    }

    /* SETTER FUNCTIONS */
    function setMonetaryPolicy(address monetaryPolicy_) external onlyOwner {
        monetaryPolicy = monetaryPolicy_;
        emit LogMonetaryPolicyUpdated(monetaryPolicy_);
    }

    modifier onlyMonetaryPolicy() {
        require(msg.sender == monetaryPolicy);
        _;
    }

    function setDeveloperAddress(address developer_) external onlyOwner {
        developer = developer_;
        emit LogDeveloperAddress(developer_);
    }

    function setLiquidityPool(address liquidityPool_) external onlyOwner {
        liquidityPool = liquidityPool_;
        emit LogLiquidityAddress(liquidityPool_);
    }

    function setRewardContract(IRUSDRewards _rusdRewardContract)
        public
        onlyOwner
    {
        rusdRewardContract = _rusdRewardContract;
    }

    function setDeveloperPercent(uint256 sellPercent_, uint256 buyPercent_)
        external
        onlyOwner
    {
        sellDeveloperPercent = sellPercent_;
        buyDeveloperPercent = buyPercent_;
        emit LogDeveloperFee(sellPercent_, buyPercent_);
    }

    function setLiquiditypercent(
        uint256 sellLiquidityFee_,
        uint256 buyLiquidityFee_
    ) external onlyOwner {
        buyLiquidityFee = buyLiquidityFee_;
        sellLiquidityFee = sellLiquidityFee_;
        emit LogLiquidityFee(sellLiquidityFee_, buyLiquidityFee_);
    }

    function setReflectoPoolAddress(address poolAddress_) external onlyOwner {
        poolAddress = poolAddress_;
    }

    function setSellLimit(uint256 sellLimit_) external onlyOwner {
        sellLimit = sellLimit_;
    }

    function setReflectoContractAddress(address reflectoAdd_)
        external
        onlyOwner
    {
        reflectoAdd = reflectoAdd_;
    }

    function setCustomFees(
        address holder_,
        uint256 devSellFee_,
        uint256 devBuyFee_,
        uint256 rewardPoolSellFee_,
        uint256 rewardPoolBuyFee_,
        uint256 reflectoBBSellFee_,
        uint256 reflectoBBBuyFee_,
        uint256 liquiditySellFee_,
        uint256 liquidityBuyFee_,
        bool isCustomFee_
    ) external onlyOwner {
        usersFees[holder_].devSellFee = devSellFee_;
        usersFees[holder_].devBuyFee = devBuyFee_;
        usersFees[holder_].rewardPoolSellFee = rewardPoolSellFee_;
        usersFees[holder_].rewardPoolBuyFee = rewardPoolBuyFee_;
        usersFees[holder_].reflectoBBSellFee = reflectoBBSellFee_;
        usersFees[holder_].reflectoBBBuyFee = reflectoBBBuyFee_;
        usersFees[holder_].liquiditySellFee = liquiditySellFee_;
        usersFees[holder_].liquidityBuyFee = liquidityBuyFee_;
        isCustomFee[holder_] = isCustomFee_;
    }

    function setBuySellFee(
        uint256 buyBackPool_,
        uint256 buyBackContract_,
        uint256 sellBackPool_,
        uint256 sellBackContract_
    ) external onlyOwner {
        buyBackPool = buyBackPool_;
        buyBackContract = buyBackContract_;
        sellBackPool = sellBackPool_;
        sellBackContract = sellBackContract_;
    }

    function addProviderPair(IProviderPair _providerPair) external onlyOwner {
        require(providerPairs.length <= 30, "cannot add more than 30");
        providerPairs.push(_providerPair);
    }

    function rebase(uint256 epoch, int256 supplyDelta)
        external
        onlyMonetaryPolicy
        returns (uint256)
    {
        if (supplyDelta == 0) {
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        }

        if (supplyDelta < 0) {
            // reduce the supply
            _totalSupply = _totalSupply.sub(uint256(supplyDelta.abs()));
        } else {
            // add to the supply
            _totalSupply = _totalSupply.add(uint256(supplyDelta));
        }

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _fracsPerRUSD = TOTAL_FRAC.div(_totalSupply);
        // The applied supplyDelta can deviate from the requested supplyDelta,
        // but this deviation is guaranteed to be < (_totalSupply^2)/(TOTAL_FRAC - _totalSupply).
        //
        // In the case of _totalSupply <= MAX_UINT128 (our current supply cap), this
        // deviation is guaranteed to be < 1, so we can omit this step. If the supply cap is
        // ever increased, it must be re-included.
        // _totalSupply = TOTAL_FRAC.div(_fracsPerRUSD)
        rusdRewardContract._updateRewardsPerToken();
        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    function initialize(address owner_, IRUSDRewards _rusdRewardContract)
        public
        initializer
    {
        rusdRewardContract = _rusdRewardContract;
        ERC20Detailed.initialize("REFLECTO USD", "RUSD", uint8(DECIMALS));
        Ownable.initialize(owner_);

        sellLimit = 200000000000;

        sellDeveloperPercent = 10; //0.1%
        buyDeveloperPercent = 10; //0.1%
        sellLiquidityFee = 300; //3%
        buyLiquidityFee = 300; //3%
        buyBackPool = 25; //0.25%   RUSD will be converted to Reflecto and goes into the pool
        buyBackContract = 25; //0.25%   RUSD is converted into BNB and BNB is stored in Reflecto contract
        sellBackPool = 25; //0.25%
        sellBackContract = 25; //0.25%

        _totalSupply = INITIAL_FRACTIONS_SUPPLY; // 50m
        _fracBalances[owner_] = TOTAL_FRAC; // 50m
        _fracsPerRUSD = TOTAL_FRAC.div(_totalSupply); // how many fracs make up 1 Fraction
        emit Transfer(address(0x0), owner_, _totalSupply);
    }

    /**
     * @return The total number of Fractions.
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @param who The address to query.
     * @return The balance of the specified address.
     */
    function balanceOf(address who) external view override returns (uint256) {
        return _fracBalances[who].div(_fracsPerRUSD);
    }

    /**
     * @param who The address to query.
     * @return The fracs balance of the specified address.
     */
    function scaledBalanceOf(address who) external view returns (uint256) {
        return _fracBalances[who];
    }

    /**
     * @return the total number of fracs.
     */
    function scaledTotalSupply() external pure returns (uint256) {
        return TOTAL_FRAC;
    }

    function getChainID() external view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    /**
     * @return The computed DOMAIN_SEPARATOR to be used off-chain services
     *         which implement EIP-712.
     *         https://eips.ethereum.org/EIPS/eip-2612
     **/
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN,
                    keccak256(bytes(name())),
                    keccak256(bytes(EIP712_REVISION)),
                    chainId,
                    address(this)
                )
            );
    }

    function mint(address _to, uint256 _value) external onlyMonetaryPolicy {
        uint256 fracValue = _value.mul(_fracsPerRUSD);
        _fracBalances[_to] = _fracBalances[_to].add(fracValue);
        _totalSupply = _totalSupply.add(_value);
    }

    function burn(address _to, uint256 _value) external onlyMonetaryPolicy {
        uint256 fracValue = _value.mul(_fracsPerRUSD);
        require(
            _fracBalances[_to] >= fracValue,
            "Value must be less then balance"
        );
        _fracBalances[_to] = _fracBalances[_to].sub(fracValue);
        _totalSupply = _totalSupply.sub(_value);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 value,
        Fees memory usersFees
    ) internal virtual {
        uint256 fracValue = value.mul(_fracsPerRUSD);
        _fracBalances[sender] = _fracBalances[sender].sub(fracValue);
        uint256 fracDeveloper;
        uint256 fracLiquidity;
        uint256 fracTo;
        uint256 poolFee;
        uint256 contractFee;

        if (block.timestamp > timeOfSell[sender] + 1 days) {
            amountOfSell[sender] = 0;
        }

        if (providerPairs.length > 0) {
            for (uint8 i = 0; i < providerPairs.length; i++) {
                if (recipient == address(providerPairs[i])) {
                    require(
                        value + amountOfSell[sender] <= sellLimit,
                        "One day needs to pass to be able to sell again"
                    );
                    poolFee = (fracValue.mul(usersFees.rewardPoolSellFee)).div(
                        10000
                    );
                    contractFee = (fracValue.mul(usersFees.reflectoBBSellFee))
                        .div(10000);
                    _fracBalances[poolAddress] = _fracBalances[poolAddress].add(
                        poolFee
                    );
                    _fracBalances[reflectoAdd] = _fracBalances[reflectoAdd].add(
                        contractFee
                    );
                    fracDeveloper = (fracValue.mul(usersFees.devSellFee)).div(
                        10000
                    );
                    fracLiquidity = (fracValue.mul(usersFees.liquiditySellFee))
                        .div(10000);
                    fracTo = fracValue.sub(
                        fracDeveloper.add(fracLiquidity).add(poolFee).add(
                            contractFee
                        )
                    );
                    timeOfSell[sender] = block.timestamp;
                    amountOfSell[sender] = amountOfSell[sender] + value;
                } else if (sender == address(providerPairs[i])) {
                    poolFee = (fracValue.mul(usersFees.rewardPoolBuyFee)).div(
                        10000
                    );
                    contractFee = (fracValue.mul(usersFees.reflectoBBBuyFee))
                        .div(10000);
                    _fracBalances[poolAddress] = _fracBalances[poolAddress].add(
                        poolFee
                    );
                    _fracBalances[reflectoAdd] = _fracBalances[reflectoAdd].add(
                        contractFee
                    );
                    fracDeveloper = (fracValue.mul(usersFees.devBuyFee)).div(
                        10000
                    );
                    fracLiquidity = (fracValue.mul(usersFees.liquidityBuyFee))
                        .div(10000);
                    fracTo = fracValue.sub(
                        fracDeveloper.add(fracLiquidity).add(poolFee).add(
                            contractFee
                        )
                    );
                } else {
                    fracDeveloper = (fracValue.mul(usersFees.devBuyFee)).div(
                        10000
                    );
                    fracLiquidity = (fracValue.mul(usersFees.liquidityBuyFee))
                        .div(10000);
                    fracTo = fracValue.sub(fracDeveloper.add(fracLiquidity));
                }
            }
        } else {
            fracDeveloper = (fracValue.mul(usersFees.devBuyFee)).div(10000);
            fracLiquidity = (fracValue.mul(usersFees.liquidityBuyFee)).div(
                10000
            );
            fracTo = fracValue.sub(fracDeveloper.add(fracLiquidity));
        }
        _fracBalances[developer] = _fracBalances[developer].add(fracDeveloper);
        _fracBalances[liquidityPool] = _fracBalances[liquidityPool].add(
            fracLiquidity
        );
        _fracBalances[recipient] = _fracBalances[recipient].add(fracTo);

        rusdRewardContract._updateRewardsPerToken();
        rusdRewardContract._updateUserRewards(sender);
        rusdRewardContract._updateUserRewards(recipient);

        emit Transfer(sender, recipient, fracTo.div(_fracsPerRUSD));
        emit Transfer(sender, developer, fracDeveloper.div(_fracsPerRUSD));
        emit Transfer(sender, liquidityPool, fracLiquidity.div(_fracsPerRUSD));
        emit Transfer(sender, poolAddress, poolFee.div(_fracsPerRUSD));
        emit Transfer(sender, reflectoAdd, contractFee.div(_fracsPerRUSD));
    }

    function _normalTransfer(
        address _from,
        address _to,
        uint256 _value
    ) internal virtual {
        uint256 fracValue = _value.mul(_fracsPerRUSD);

        _fracBalances[_from] = _fracBalances[_from].sub(fracValue);
        _fracBalances[_to] = _fracBalances[_to].add(fracValue);

        emit Transfer(_from, _to, _value);
    }

    /**
     * @dev Transfer tokens to a specified address.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     * @return True on success, false otherwise.
     */
    function transfer(address to, uint256 value)
        external
        override
        validRecipient(to)
        returns (bool)
    {
        if (isExcludedFromAllFees[msg.sender] || isExcludedFromAllFees[to]) {
            _normalTransfer(msg.sender, to, value);
        } else {
            if (isCustomFee[msg.sender]) {
                _transfer(msg.sender, to, value, usersFees[msg.sender]);
            } else if (isCustomFee[to]) {
                _transfer(msg.sender, to, value, usersFees[to]);
            } else {
                Fees memory uFees = Fees(
                    sellDeveloperPercent,
                    buyDeveloperPercent,
                    sellBackPool,
                    buyBackPool,
                    sellBackContract,
                    buyBackContract,
                    sellLiquidityFee,
                    buyLiquidityFee
                );
                _transfer(msg.sender, to, value, uFees);
            }
        }
        return true;
    }

    function removeProvider(IProviderPair _providerPair) external onlyOwner{
        bool flag=false;
        for(uint8 i=0;i < providerPairs.length; i++){
            if(providerPairs[i]== _providerPair){
                providerPairs[i]= providerPairs[providerPairs.length-1];
                providerPairs.pop();
                flag = false;
                break;
            }else{
                flag = true;
         }
        }
        if(flag==true){
            revert();
        }
    }

    /**
     * @dev Function to check the amount of tokens that an owner has allowed to a spender.
     * @param owner_ The address which owns the funds.
     * @param spender The address which will spend the funds.
     * @return The number of tokens still available for the spender.
     */
    function allowance(address owner_, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowedFractions[owner_][spender];
    }

    /**x
     * @dev Transfer tokens from one address to another.
     * @param from The address you want to send tokens from.
     * @param to The address you want to transfer to.
     * @param value The amount of tokens to be transferred.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override validRecipient(to) returns (bool) {
        if (isExcludedFromAllFees[from] || isExcludedFromAllFees[to]) {
            _normalTransfer(from, to, value);
        } else {
            if (isCustomFee[from]) {
                _transfer(from, to, value, usersFees[from]);
            } else if (isCustomFee[to]) {
                _transfer(from, to, value, usersFees[to]);
            } else {
                Fees memory uFees = Fees(
                    sellDeveloperPercent,
                    buyDeveloperPercent,
                    sellBackPool,
                    buyBackPool,
                    sellBackContract,
                    buyBackContract,
                    sellLiquidityFee,
                    buyLiquidityFee
                );
                _transfer(from, to, value, uFees);
            }
        }
        _allowedFractions[from][msg.sender] = _allowedFractions[from][
            msg.sender
        ].sub(value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of
     * msg.sender. This method is included for ERC20 compatibility.
     * increaseAllowance and decreaseAllowance should be used instead.
     * Changing an allowance with this method brings the risk that someone may transfer both
     * the old and the new allowance - if they are both greater than zero - if a transfer
     * transaction is mined before the later approve() call is mined.
     *
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value)
        external
        override
        returns (bool)
    {
        _allowedFractions[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner has allowed to a spender.
     * This method should be used instead of approve() to avoid the double approval vulnerability
     * described above.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        returns (bool)
    {
        _allowedFractions[msg.sender][spender] = _allowedFractions[msg.sender][
            spender
        ].add(addedValue);

        emit Approval(
            msg.sender,
            spender,
            _allowedFractions[msg.sender][spender]
        );
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner has allowed to a spender.
     *
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        uint256 oldValue = _allowedFractions[msg.sender][spender];
        _allowedFractions[msg.sender][spender] = (subtractedValue >= oldValue)
            ? 0
            : oldValue.sub(subtractedValue);

        emit Approval(
            msg.sender,
            spender,
            _allowedFractions[msg.sender][spender]
        );
        return true;
    }

    // --- Approve by signature ---
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH_META,
                        holder,
                        spender,
                        nonce,
                        expiry,
                        allowed
                    )
                )
            )
        );

        require(holder != address(0), "Reflecto/invalid-address-0");
        require(
            holder == ecrecover(digest, v, r, s),
            "Reflecto/invalid-permit"
        );
        require(
            expiry == 0 || block.timestamp <= expiry,
            "Reflecto/permit-expired"
        );
        require(nonce == nonces[holder]++, "Reflecto/invalid-nonce");
        uint256 wad = allowed ? _totalSupply : 0;

        _allowedFractions[holder][spender] = wad;
        emit Approval(holder, spender, wad);
    }

    function convertTokenToBuyBack(address wbnb, address token, address routerAddress) external onlyOwner {
        address[] memory bnbPath = new address[](2);
        bnbPath[0] = token;
        bnbPath[1] = wbnb;
        uint256 amountIn = IERC20(token).balanceOf(address(this));

        uint256 deadline = block.timestamp + 1000;
        IERC20(token).approve(routerAddress, amountIn);
        
        IRouter(routerAddress).swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            0,
            bnbPath,
            reflectoAdd,
            deadline
        );
    }
}

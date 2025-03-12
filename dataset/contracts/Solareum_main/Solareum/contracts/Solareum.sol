// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./dex/IDexFactory.sol";
import "./dex/IDexRouter.sol";
import "./dex/IDexPair.sol";
import "./TokenHandler.sol";

/// @custom:security-contact michaelnlcrypto@gmail.com
/**
 * @title uFragments ERC20 token
 * @dev This is originally based on an implementation of the uFragments Ideal Money protocol.
 *      uFragments is a normal ERC20 token, but its supply can be adjusted by splitting and
 *      combining tokens proportionally across all wallets.
 *
 *      uFragment balances are internally represented with a hidden denomination, 'gons'.
 *      We support splitting the currency in expansion and combining the currency on contraction by
 *      changing the exchange rate between the hidden 'gons' and the public 'fragments'.
 */
contract Solareum is
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    bool public tradingActive;
    bool public swapEnabled;

    uint256 public rewardYield;
    uint256 public rewardYieldDenominator;

    uint256 public rebaseFrequency;
    uint256 public nextRebase;
    bool public rebaseEnabled;
    bool public autoRebase;

    uint256 public timeBetweenRebaseReduction;
    uint256 public rebaseReductionAmount;
    uint256 public lastReduction;

    mapping(address => bool) _isFeeExempt;
    address[] public _makerPairs;
    mapping(address => bool) public automatedMarketMakerPairs;

    uint256 public constant MAX_FEE_RATE = 50;
    uint256 private constant MAX_UINT256 = type(uint256).max;
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 33_618_820 * (10 ** 18);
    uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);
    uint256 private constant MAX_SUPPLY = 100_000_000 * (10 ** 18);

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    address public marketingAndDevAddress;
    address public pairedToken;

    IDexRouter public router;
    address public pair;

    TokenHandler public tokenHandler;

    uint256 public liquidityFee;
    uint256 public marketingAndDevFee;
    uint256 public totalFee;

    bool inSwap;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    uint256 private _totalSupply;
    uint256 private _gonsPerFragment;
    uint256 private gonSwapThreshold;

    mapping(address => uint256) private _gonBalances;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _dexAddress, address _pairedToken, address _marketingAndDevAddress) public initializer {
        __ERC20_init("Solareum", "SRM");
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        tradingActive = false;
        swapEnabled = true;

        rewardYield =               457691500;
        rewardYieldDenominator =    100000000000; //1^11

        rebaseFrequency = 1 days / 2; // 43200 seconds - every 12 hours
        nextRebase = block.timestamp + rebaseFrequency;
        rebaseEnabled = false;
        autoRebase = true;

        timeBetweenRebaseReduction = 60 days; // 60 days
        rebaseReductionAmount = 50; // 50% reduction

        liquidityFee = 30;
        marketingAndDevFee = 20;
        totalFee = liquidityFee + marketingAndDevFee;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        // _mint(msg.sender, 100000000000 * 10 ** decimals());

        router = IDexRouter(_dexAddress);
        pairedToken = _pairedToken;
        marketingAndDevAddress = _marketingAndDevAddress;

        tokenHandler = new TokenHandler();

        _approve(address(this), address(router), ~uint256(0));
        _approve(_msgSender(), address(router), ~uint256(0));
        _approve(address(this), address(this), ~uint256(0));

        _isFeeExempt[address(this)] = true;
        _isFeeExempt[address(msg.sender)] = true;
        _isFeeExempt[address(_dexAddress)] = true;

        gonSwapThreshold = ((TOTAL_GONS / 100000) * 25);
        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[msg.sender] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS / (_totalSupply);
        emit Transfer(address(0x0), msg.sender, balanceOf(msg.sender));
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // The following functions are overrides required by Solidity.

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address who) public view override returns (uint256) {
        return _gonBalances[who] / (_gonsPerFragment);
    }

    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }

    function checkSwapThreshold() external view returns (uint256) {
        return gonSwapThreshold / (_gonsPerFragment);
    }

    function shouldRebase() public view returns (bool) {
        return nextRebase <= block.timestamp;
    }

    function shouldTakeFee(address from, address to) internal view returns (bool) {
        if (_isFeeExempt[from] || _isFeeExempt[to]) {
            return false;
        } else {
            return (automatedMarketMakerPairs[from] || automatedMarketMakerPairs[to]);
        }
    }

    function shouldSwapBack() internal view returns (bool) {
        return !inSwap && swapEnabled && totalFee > 0 && _gonBalances[address(this)] >= gonSwapThreshold;
    }

    function manualSync() public {
        for (uint i = 0; i < _makerPairs.length; i++) {
            try IDexPair(_makerPairs[i]).sync() {} catch {}
        }
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal whenNotPaused() override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        if (!tradingActive) {
            require(_isFeeExempt[sender] || _isFeeExempt[recipient], "Trading is paused");
        }

        if (!_isFeeExempt[sender] && !_isFeeExempt[recipient] && shouldSwapBack() && !automatedMarketMakerPairs[sender]) {
            inSwap = true;
            swapBack();
            inSwap = false;
        }

        if (autoRebase && !automatedMarketMakerPairs[sender] && !inSwap && shouldRebase() && !_isFeeExempt[recipient] && !_isFeeExempt[sender]) {
            rebase();
        }

        uint256 gonAmount = amount * _gonsPerFragment;
        uint256 fromBalance = _gonBalances[sender];
        require(fromBalance >= gonAmount, "ERC20: transfer amount exceeds balance");

        _gonBalances[sender] = _gonBalances[sender] - (gonAmount);

        uint256 gonAmountReceived = shouldTakeFee(sender, recipient) ? takeFee(sender, gonAmount) : gonAmount;
        _gonBalances[recipient] = _gonBalances[recipient] + (gonAmountReceived);

        emit Transfer(sender, recipient, gonAmountReceived / (_gonsPerFragment));
    }

    function swapBack() public {
        uint256 contractBalance = balanceOf(address(this));
        if (contractBalance > (gonSwapThreshold / (_gonsPerFragment)) * 20) {
            contractBalance = (gonSwapThreshold / (_gonsPerFragment)) * 20;
        }

        uint256 tokensForLiquidity = (contractBalance * liquidityFee) / totalFee;
        if (tokensForLiquidity > 0 && contractBalance >= tokensForLiquidity) {
            _transfer(address(this), pair, tokensForLiquidity);
            manualSync();
            contractBalance -= tokensForLiquidity;
            tokensForLiquidity = 0;
        }

        swapTokensForPairedToken(contractBalance);

        tokenHandler.sendTokenToOwner(address(pairedToken));
        
        uint256 pairedTokenBalance = IERC20(pairedToken).balanceOf(address(this));
        if (pairedTokenBalance > 0) {
            IERC20(pairedToken).transfer(marketingAndDevAddress, pairedTokenBalance);
        }
    }

    function swapTokensForPairedToken(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(pairedToken);

        // make the swap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount
            path,
            address(tokenHandler),
            block.timestamp
        );
    }

    function takeFee(address sender, uint256 gonAmount) internal returns (uint256) {
        if (totalFee == 0) return gonAmount;
        uint256 feeAmount = (gonAmount / 1000) * totalFee;

        _gonBalances[address(this)] = _gonBalances[address(this)] + (feeAmount);
        emit Transfer(sender, address(this), feeAmount / (_gonsPerFragment));

        return gonAmount - (feeAmount);
    }

    function getSupplyDeltaOnNextRebase() external view returns (uint256) {
        return (_totalSupply * rewardYield) / rewardYieldDenominator;
    }

    function rebase() private returns (uint256) {
        if (!rebaseEnabled) return _totalSupply;

        uint256 epoch = block.timestamp;

        if (lastReduction + timeBetweenRebaseReduction <= block.timestamp) {
            rewardYield -= (rewardYield * rebaseReductionAmount) / 100;
            lastReduction = block.timestamp;
        }

        uint256 supplyDelta = (_totalSupply * rewardYield) / rewardYieldDenominator;

        nextRebase = nextRebase + rebaseFrequency;

        if (supplyDelta == 0) {
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        }

        _totalSupply = _totalSupply + supplyDelta;

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _gonsPerFragment = TOTAL_GONS / (_totalSupply);

        manualSync();

        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    function manualRebase() external {
        require(!inSwap, "Try again");
        require(shouldRebase(), "Not in time");
        rebase();
    }

    function setAutomatedMarketMakerPair(address _pair, bool _value, bool _defaultPair) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_pair != address(0), "Zero address");
        require(automatedMarketMakerPairs[_pair] != _value, "Value already set");

        automatedMarketMakerPairs[_pair] = _value;

        if (_value) {
            _makerPairs.push(_pair);
            if (_defaultPair) {
                pair = _pair;
                _approve(address(this), _pair, ~uint256(0));
            }
        } else {
            require(_makerPairs.length > 1, "Required 1 pair");
            for (uint256 i = 0; i < _makerPairs.length; i++) {
                if (_makerPairs[i] == _pair) {
                    _makerPairs[i] = _makerPairs[_makerPairs.length - 1];
                    _makerPairs.pop();
                    break;
                }
            }
        }

        emit SetAutomatedMarketMakerPair(_pair, _value);
    }

    function setRebasing(bool _rebaseEnabled, bool _autoRebase) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!rebaseEnabled && _rebaseEnabled) {
            nextRebase = block.timestamp + rebaseFrequency;
            lastReduction = block.timestamp;
        }

        rebaseEnabled = _rebaseEnabled;
        autoRebase = _autoRebase;
    }

    function setTradingEnabled(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tradingActive != enabled, "Trading already at value");
        require(pair != address(0), "Default pair not set yet");
        tradingActive = enabled;
    }

    function setFeeExempt(address _addr, bool _value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_isFeeExempt[_addr] != _value, "Not changed");
        _isFeeExempt[_addr] = _value;
    }

    function setFeeReceivers(address _marketingAndDevAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_marketingAndDevAddress != address(0), "zero address");
        marketingAndDevAddress = _marketingAndDevAddress;
    }

    function setFees(uint256 _liquidityFee, uint256 _marketingAndDevFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        liquidityFee = _liquidityFee;
        marketingAndDevFee = _marketingAndDevFee;
        totalFee = liquidityFee + marketingAndDevFee;
        require(totalFee <= MAX_FEE_RATE, "Fees set too high");
    }

    function retrieveToken(address tokenAddress, uint256 tokens, address destination) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool success) {
        require(tokenAddress != address(this), "Cannot take native tokens");
        return IERC20(tokenAddress).transfer(destination, tokens);
    }

    function setNextRebase(uint256 _nextRebase) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_nextRebase > block.timestamp, "Must set rebase in the future");
        nextRebase = _nextRebase;
    }
}

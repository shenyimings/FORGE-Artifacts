// SPDX-License-Identifier: MIT
//
// BasedRate
// website.: www.basedrate.io
// telegram.: https://t.me/BasedRate
//               _
//              (_)
//               |
//          ()---|---()
//               |
//               |
//        __     |     __
//       |\     /^\     /|
//         '..-'   '-..'
//           `-._ _.-`
//               `

pragma solidity 0.8.19;

import "./interfaces/IOracle.sol";
import "./libraries/SafeMath8.sol";
import "./libraries/Operator.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

// import "hardhat/console.sol";

contract BaseRate is ERC20Burnable, Operator {
    using SafeMath8 for uint8;
    using SafeMath for uint256;

    address public taxManager;
    address public oracle;

    // Initial presale distribution
    uint256 public constant INITIAL_PRESALE_DISTRIBUTION = 33.825 ether;
    uint256 public constant INITIAL_LIQUIDITY_DISTRIBUTION = 25 ether;

    // Should the taxes be calculated using the tax tiers
    bool public autoCalculateTax;
    mapping(address => bool) public isLP;

    // Current tax rate
    uint256 public taxRate;

    // Tax Tiers
    uint256[] public taxTiersTwaps = [
        0,
        5e17,
        6e17,
        7e17,
        8e17,
        9e17,
        9.5e17,
        1e18,
        1.05e18,
        1.10e18,
        1.20e18,
        1.30e18,
        1.40e18,
        1.50e18
    ];
    uint256[] public taxTiersRates = [
        2000,
        1900,
        1600,
        1200,
        1000,
        1000,
        500,
        250,
        200,
        175,
        150,
        125,
        125,
        100
    ];

    // Sender addresses excluded from Tax
    mapping(address => bool) public excludedAddresses;

    modifier onlyTaxManager() {
        require(taxManager == _msgSender(), "Caller is not the tax office");
        _;
    }

    function setTaxManager(address _taxManager) public onlyTaxManager {
        taxManager = _taxManager;
    }

    bool public rewardPoolDistributed = false;

    constructor() ERC20("BasedRate.io RATE", "BRATE") {
        taxManager = _msgSender();
        _mint(_msgSender(), INITIAL_PRESALE_DISTRIBUTION);
        _mint(_msgSender(), INITIAL_LIQUIDITY_DISTRIBUTION);
    }

    /* ============= Taxation ============= */

    function getTaxTiersTwapsCount() public view returns (uint256 count) {
        return taxTiersTwaps.length;
    }

    function getTaxTiersRatesCount() public view returns (uint256 count) {
        return taxTiersRates.length;
    }

    function isAddressExcluded(address _address) public view returns (bool) {
        return excludedAddresses[_address];
    }

    function setTaxTiersTwap(
        uint8 _index,
        uint256 _value
    ) public onlyTaxManager returns (bool) {
        require(_index >= 0, "Index has to be higher than 0");
        require(
            _index < getTaxTiersTwapsCount(),
            "Index has to lower than count of tax tiers"
        );
        if (_index > 0) {
            require(_value > taxTiersTwaps[_index - 1]);
        }
        if (_index < getTaxTiersTwapsCount().sub(1)) {
            require(_value < taxTiersTwaps[_index + 1]);
        }
        taxTiersTwaps[_index] = _value;
        return true;
    }

    function setTaxTiersRate(
        uint8 _index,
        uint256 _value
    ) public onlyTaxManager returns (bool) {
        require(_index >= 0, "Index has to be higher than 0");
        require(
            _index < getTaxTiersRatesCount(),
            "Index has to lower than count of tax tiers"
        );
        taxTiersRates[_index] = _value;
        return true;
    }

    function _getBratePrice() internal view returns (uint256 _bratePrice) {
        try IOracle(oracle).twap(address(this), 1e18) returns (uint144 _price) {
            return uint256(_price);
        } catch {
            revert("Brate: failed to fetch BRATE price from Oracle");
        }
    }

    function _updateTaxRate(uint256 _bratePrice) internal returns (uint256) {
        for (
            uint8 tierId = uint8(getTaxTiersTwapsCount()).sub(1);
            tierId >= 0;
            --tierId
        ) {
            if (_bratePrice >= taxTiersTwaps[tierId]) {
                require(
                    taxTiersRates[tierId] < 10000,
                    "tax equal or bigger to 100%"
                );
                taxRate = taxTiersRates[tierId];
                return taxTiersRates[tierId];
            }
        }
        return 0;
    }

    function setLP(address _LP, bool _isLP) public onlyTaxManager {
        isLP[_LP] = _isLP;
    }

    function enableAutoCalculateTax() public onlyTaxManager {
        autoCalculateTax = true;
    }

    function disableAutoCalculateTax() public onlyTaxManager {
        autoCalculateTax = false;
    }

    function setOracle(address _oracle) public onlyTaxManager {
        require(_oracle != address(0), "oracle address cannot be 0 address");
        oracle = _oracle;
    }

    function setTaxRate(uint256 _taxRate) public onlyTaxManager {
        require(!autoCalculateTax, "auto calculate tax cannot be enabled");
        require(_taxRate <= 2000, "tax equal or bigger to 20%");
        taxRate = _taxRate;
    }

    function excludeAddress(
        address _address
    ) public onlyTaxManager returns (bool) {
        require(!excludedAddresses[_address], "address can't be excluded");
        excludedAddresses[_address] = true;
        return true;
    }

    function includeAddress(
        address _address
    ) public onlyTaxManager returns (bool) {
        require(excludedAddresses[_address], "address can't be included");
        excludedAddresses[_address] = false;
        return true;
    }

    function mint(
        address recipient,
        uint256 amount
    ) public onlyOperator returns (bool) {
        _mint(recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transferBRATE(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            allowance(sender, _msgSender()).sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );

        return true;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        address sender = _msgSender();
        _transferBRATE(sender, recipient, amount);
        return true;
    }

    function _transferWithTax(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        uint256 taxAmount = amount.mul(taxRate).div(10000);
        uint256 amountAfterTax = amount.sub(taxAmount);
        _burn(sender, taxAmount);
        _transfer(sender, recipient, amountAfterTax);
    }

    function _transferBRATE(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        uint256 currentTaxRate = 0;
        if (autoCalculateTax) {
            uint256 currentBratePrice = _getBratePrice();
            currentTaxRate = _updateTaxRate(currentBratePrice);
        }
        if (!autoCalculateTax) {
            currentTaxRate = taxRate;
        }
        if (
            (isLP[recipient]) &&
            currentTaxRate != 0 &&
            !excludedAddresses[sender] &&
            !excludedAddresses[recipient]
        ) {
            _transferWithTax(sender, recipient, amount);
        } else {
            _transfer(sender, recipient, amount);
        }
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOwner {
        _token.transfer(_to, _amount);
    }
}

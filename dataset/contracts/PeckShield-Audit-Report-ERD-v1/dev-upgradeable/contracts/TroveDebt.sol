// SPDX-License-Identifier: MITs
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "./Interfaces/ITroveDebt.sol";
import "./Interfaces/ITroveManager.sol";
import "./Dependencies/WadRayMath.sol";

contract TroveDebt is ContextUpgradeable, OwnableUpgradeable, ITroveDebt {
    using SafeMathUpgradeable for uint256;
    using WadRayMath for uint256;

    ITroveManager internal troveManager;

    mapping(address => uint256) internal _balances;

    uint256 internal _totalSupply;

    /**
     * @dev Only troveManager can call functions marked by this modifier
     **/
    modifier onlyTroveManager() {
        require(
            _msgSender() == address(troveManager),
            "Errors.CT_CALLER_MUST_BE_LENDING_POOL"
        );
        _;
    }

    function initialize() public initializer {
        __Ownable_init();
    }

    function setAddress(address _troveManagerAddress) external onlyOwner {
        troveManager = ITroveManager(_troveManagerAddress);
    }

    function balanceOf(
        address user
    ) public view virtual override returns (uint256) {
        uint256 scaledBalance = _balances[user];
        if (scaledBalance == 0) {
            return 0;
        }
        return scaledBalance.rayMul(troveManager.getTroveNormalizedDebt());
    }

    function addDebt(
        address user,
        uint256 amount,
        uint256 index
    ) external override onlyTroveManager returns (bool) {
        uint256 previousBalance = _balances[user];
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, "Errors.CT_INVALID_MINT_AMOUNT");

        uint256 oldTotalSupply = _totalSupply;
        _totalSupply = oldTotalSupply.add(amountScaled);

        uint256 oldAccountBalance = _balances[user];
        _balances[user] = oldAccountBalance.add(amountScaled);

        return previousBalance == 0;
    }

    function subDebt(
        address user,
        uint256 amount,
        uint256 index
    ) external override onlyTroveManager {
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, "Errors.CT_INVALID_BURN_AMOUNT");

        uint256 oldTotalSupply = _totalSupply;
        _totalSupply = oldTotalSupply.sub(amountScaled);

        uint256 oldAccountBalance = _balances[user];
        _balances[user] = oldAccountBalance.sub(amountScaled);
    }

    /**
     * @dev Returns the principal debt balance of the user from
     * @return The debt balance of the user since the last burn/mint action
     **/
    function scaledBalanceOf(
        address user
    ) public view virtual override returns (uint256) {
        return _balances[user];
    }

    /**
     * @dev Returns the total supply of the variable debt token. Represents the total debt accrued by the users
     * @return The total supply
     **/
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply.rayMul(troveManager.getTroveNormalizedDebt());
    }

    /**
     * @dev Returns the scaled total supply of the variable debt token. Represents sum(debt/index)
     * @return the scaled total supply
     **/
    function scaledTotalSupply()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _totalSupply;
    }

    /**
     * @dev Returns the principal balance of the user and principal total supply.
     * @param user The address of the user
     * @return The principal balance of the user
     * @return The principal total supply
     **/
    function getScaledUserBalanceAndSupply(
        address user
    ) external view override returns (uint256, uint256) {
        return (_balances[user], _totalSupply);
    }
}

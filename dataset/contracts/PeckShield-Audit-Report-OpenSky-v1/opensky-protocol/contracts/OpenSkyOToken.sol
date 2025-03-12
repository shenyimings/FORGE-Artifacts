// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

import './libraries/math/WadRayMath.sol';

import './interfaces/IOpenSkySettings.sol';
import './interfaces/IOpenSkyOToken.sol';
import './interfaces/IOpenSkyPool.sol';
import './interfaces/IOpenSkyIncentivesController.sol';
import './interfaces/IOpenSkyMoneymarket.sol';

contract OpenSkyOToken is Context, ERC20Burnable, ERC721Holder, IOpenSkyOToken {
    using WadRayMath for uint256;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    IOpenSkySettings public immutable SETTINGS;

    address internal _pool;
    uint256 internal _reserveId;
    IOpenSkyIncentivesController internal _incentivesController;

    modifier onlyPool() {
        require(_msgSender() == address(_pool), Errors.ACL_ONLY_POOL_CAN_CALL);
        _;
    }

    constructor(
        address pool,
        uint256 reserveId,
        string memory name,
        string memory symbol,
        address incentiveController,
        address settings
    ) ERC20(name, symbol) {
        _pool = pool;
        _reserveId = reserveId;
        _incentivesController = IOpenSkyIncentivesController(incentiveController);
        SETTINGS = IOpenSkySettings(settings);
    }

    function _treasury() internal view returns (address) {
        return SETTINGS.treasuryAddress();
    }

    function mint(
        address account,
        uint256 amount,
        uint256 index
    ) public virtual override onlyPool {
        uint256 amountScaled = amount.rayDivTruncate(index);
        require(amountScaled != 0, Errors.AMOUNT_SCALED_IS_ZERO);

        _mint(account, amountScaled);
    }

    function _mint(address account, uint256 amount) internal virtual override {
        uint256 previousBalance = super.balanceOf(account);
        uint256 previousTotalSupply = super.totalSupply();

        super._mint(account, amount);

        if (address(_incentivesController) != address(0)) {
            _incentivesController.handleAction(account, previousBalance, previousTotalSupply);
        }
    }

    function burn(
        address account,
        uint256 amount,
        uint256 index
    ) public virtual override onlyPool {
        uint256 amountScaled = amount.rayDivTruncate(index);
        require(amountScaled != 0, Errors.AMOUNT_SCALED_IS_ZERO);

        _burn(account, amountScaled);
    }

    function _burn(address account, uint256 amount) internal virtual override {
        uint256 previousBalance = super.balanceOf(account);
        uint256 previousTotalSupply = super.totalSupply();

        super._burn(account, amount);

        if (address(_incentivesController) != address(0)) {
            _incentivesController.handleAction(account, previousBalance, previousTotalSupply);
        }
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        uint256 index = IOpenSkyPool(_pool).getReserveNormalizedIncome(_reserveId);

        uint256 amountScaled = amount.rayDivTruncate(index);
        require(amountScaled != 0, Errors.AMOUNT_SCALED_IS_ZERO);
        require(amountScaled <= type(uint128).max, Errors.AMOUNT_TRANSFER_OWERFLOW);

        uint256 previousSenderBalance = super.balanceOf(sender);
        uint256 previousRecipientBalance = super.balanceOf(recipient);

        super._transfer(sender, recipient, amountScaled);

        if (address(_incentivesController) != address(0)) {
            uint256 currentTotalSupply = super.totalSupply();
            _incentivesController.handleAction(sender, currentTotalSupply, previousSenderBalance);
            if (sender != recipient) {
                _incentivesController.handleAction(recipient, currentTotalSupply, previousRecipientBalance);
            }
        }
    }

    function mintToTreasury(uint256 amount, uint256 index) external override onlyPool {
        if (amount == 0) {
            return;
        }

        _mint(_treasury(), amount.rayDivTruncate(index));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // called only by pool
    function deposit(uint256 amount) external payable override onlyPool {
        address moneyMarket = IOpenSkyPool(_pool).getReserveData(_reserveId).moneyMarketAddress;

        (bool success, bytes memory result) = address(moneyMarket).delegatecall(
            abi.encodeWithSignature('depositCall(uint256)', amount)
        );
        require(success, Errors.MONEY_MARKET_DELEGATE_CALL_ERROR);
    }

    function withdraw(uint256 amount, address to) external override onlyPool {
        address moneyMarket = IOpenSkyPool(_pool).getReserveData(_reserveId).moneyMarketAddress;

        (bool success, bytes memory result) = address(moneyMarket).delegatecall(
            abi.encodeWithSignature('withdrawCall(uint256)', amount)
        );
        require(success, Errors.MONEY_MARKET_DELEGATE_CALL_ERROR);

        _safeTransferETH(to, amount);
    }

    function balanceOf(address account) public view override(ERC20, IERC20) returns (uint256) {
        uint256 index = IOpenSkyPool(_pool).getReserveNormalizedIncome(_reserveId);
        return super.balanceOf(account).mul(index).div(WadRayMath.ray());
    }

    function scaledBalanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }

    function principleBalanceOf(address account) public view override returns (uint256) {
        uint256 curreBalanceScaled = super.balanceOf(account);
        uint256 lastSupplyIndex = IOpenSkyPool(_pool).getReserveData(_reserveId).lastSupplyIndex;
        return curreBalanceScaled.rayMul(lastSupplyIndex);
    }

    function totalSupply() public view override(ERC20, IERC20) returns (uint256) {
        uint256 currentSupplyScaled = super.totalSupply();

        if (currentSupplyScaled == 0) {
            return 0;
        }

        return currentSupplyScaled.rayMul(IOpenSkyPool(_pool).getReserveNormalizedIncome(_reserveId));
    }

    function scaledTotalSupply() public view virtual override returns (uint256) {
        return super.totalSupply();
    }

    function principleTotalSupply() public view virtual override returns (uint256) {
        uint256 currentSupplyScaled = super.totalSupply();
        uint256 lastSupplyIndex = IOpenSkyPool(_pool).getReserveData(_reserveId).lastSupplyIndex;
        return currentSupplyScaled.rayMul(lastSupplyIndex);
    }

    /**
     * @dev Returns the scaled balance of the user and the scaled total supply.
     * @param user The address of the user
     * @return The scaled balance of the user
     * @return The scaled balance and the scaled total supply
     **/
    function getScaledUserBalanceAndSupply(address user) external view override returns (uint256, uint256) {
        return (super.balanceOf(user), super.totalSupply());
    }

    function claimERC20Rewards(address token) external {
        IERC20(token).safeTransferFrom(address(this), _treasury(), IERC20(token).balanceOf(address(this)));
    }
    function _safeTransferETH(address recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}('');
        require(success, Errors.ETH_TRANSFER_FAILED);
    }
}

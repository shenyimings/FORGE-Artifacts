pragma solidity 0.5.16;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Controllable.sol";
import "./hardworkInterface/IVault.sol";
import "./hardworkInterface/IController.sol";

contract DepositHelper is Controllable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    event DepositComplete(address holder, uint256 numberOfTransfers);

    constructor(address _storage) public Controllable(_storage) {}

    /*
     * Transfers tokens of all kinds
     */
    function depositAll(
        uint256[] memory amounts,
        address[] memory vaultAddresses,
        uint16 _referral
    ) public {
        require(
            amounts.length == vaultAddresses.length,
            "DH: amounts and vault lengths mismatch"
        );
        for (uint256 i = 0; i < vaultAddresses.length; i++) {
            if (amounts[i] == 0) {
                continue;
            }
            require(
                IController(store.controller()).hasVault(vaultAddresses[i]),
                "DH: vault is not present in controller"
            );
            IVault currentVault = IVault(vaultAddresses[i]);
            IERC20 underlying = IERC20(currentVault.underlying());

            underlying.safeTransferFrom(msg.sender, address(this), amounts[i]);
            underlying.safeApprove(address(currentVault), 0);
            underlying.safeApprove(address(currentVault), amounts[i]);
            currentVault.depositFor(amounts[i], msg.sender, _referral);
        }
    }
}

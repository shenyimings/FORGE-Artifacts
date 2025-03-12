// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@kyber.network/utils-sc/contracts/Withdrawable.sol";
import "@kyber.network/utils-sc/contracts/Utils.sol";

import "./ILending.sol";

abstract contract BaseLending is ILending, Withdrawable, Utils {
    using SafeERC20 for IERC20Ext;
    using SafeMath for uint256;

    address public proxyContract;

    event UpdatedproxyContract(address indexed _oldProxyImpl, address indexed _newProxyImpl);

    modifier onlyProxyContract() {
        require(msg.sender == proxyContract, "only proxy impl");
        _;
    }

    constructor(address _admin) Withdrawable(_admin) {}

    receive() external payable {}

    function updateProxyContract(address _proxyContract) external onlyAdmin {
        require(_proxyContract != address(0), "invalid proxy impl");
        emit UpdatedproxyContract(proxyContract, _proxyContract);
        proxyContract = _proxyContract;
    }

    function safeApproveAllowance(address spender, IERC20Ext token) internal {
        if (token != ETH_TOKEN_ADDRESS && token.allowance(address(this), spender) == 0) {
            token.safeApprove(spender, MAX_ALLOWANCE);
        }
    }

    function transferToken(
        address payable recipient,
        IERC20Ext token,
        uint256 amount
    ) internal {
        if (token == ETH_TOKEN_ADDRESS) {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "failed to transfer eth");
        } else {
            token.safeTransfer(recipient, amount);
        }
    }
}

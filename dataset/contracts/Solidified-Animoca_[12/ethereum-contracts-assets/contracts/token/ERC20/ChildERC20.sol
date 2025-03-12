// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {ERC20} from "./ERC20.sol";
import {ERC20Receiver, ChildERC20Base} from "../../bridging/ChildERC20Base.sol";

abstract contract ChildERC20 is ERC20, ChildERC20Base {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        string memory tokenURI_,
        address childChainManager
    ) ERC20(name_, symbol_, decimals_, tokenURI_) ChildERC20Base(childChainManager) {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC20, ERC20Receiver) returns (bool) {
        return ERC20.supportsInterface(interfaceId) || ERC20Receiver.supportsInterface(interfaceId);
    }

    /**
     * Called when tokens have been deposited on the root chain.
     * @dev Should handle deposit by un-escrowing the required amount for user.
     * @dev Reverts if not sent by the depositor (ChildChainManager).
     * @param user address for whom deposit has been done.
     * @param depositData abi encoded amount.
     */
    function deposit(address user, bytes calldata depositData) public virtual override {
        _requireDepositorRole(_msgSender());
        uint256 amount = abi.decode(depositData, (uint256));
        _transfer(address(this), user, amount);
    }

    /**
     * Called when user wants to withdraw tokens back to the root chain.
     * @dev Should escrow user's tokens. This transaction will be verified when exiting on root chain.
     * @dev Emits a {Withdrawn} event.
     * @param amount amount of tokens to withdraw.
     */
    function withdraw(uint256 amount) public virtual {
        address sender = _msgSender();
        _transferFrom(sender, sender, address(this), amount);
        emit Withdrawn(sender, amount);
    }

    /**
     * Called when user wants to withdraw tokens back to the root chain (no pre-approval required).
     * @dev Should escrow user's tokens. This transaction will be verified when exiting on root chain.
     * @dev Reverts if the sender is not this contract.
     * @dev Emits a {Withdrawn} event.
     * _param operator The initiator of the transfer.
     * @param from The address which transferred the tokens.
     * @param amount The amount of tokens transferred.
     * _param data Optional additional data with no specified format.
     * @return bytes4 `bytes4(keccak256("onERC20Received(address,address,uint256,bytes)"))`
     */
    function onERC20Received(
        address, /*operator*/
        address from,
        uint256 amount,
        bytes calldata /*data*/
    ) public virtual override returns (bytes4) {
        require(_msgSender() == address(this), "ChildERC20: wrong sender");
        emit Withdrawn(from, amount);
        return _ERC20_RECEIVED;
    }
}

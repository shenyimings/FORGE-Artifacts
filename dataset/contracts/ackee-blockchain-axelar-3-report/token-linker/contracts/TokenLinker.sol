// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { AxelarExecutable } from '@axelar-network/axelar-utils-solidity/contracts/executables/AxelarExecutable.sol';
import { StringToAddress, AddressToString } from '@axelar-network/axelar-utils-solidity/contracts/StringAddressUtils.sol';
import { Upgradable } from '@axelar-network/axelar-utils-solidity/contracts/upgradables/Upgradable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-utils-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IAxelarGasService } from '@axelar-network/axelar-cgp-solidity/contracts/interfaces/IAxelarGasService.sol';

abstract contract TokenLinker is AxelarExecutable, Upgradable {
    using StringToAddress for string;
    using AddressToString for address;

    IAxelarGasService public immutable gasService;
    address public immutable gatewayAddress;

    constructor(address gatewayAddress_, address gasServiceAddress_) {
        gatewayAddress = gatewayAddress_;
        gasService = IAxelarGasService(gasServiceAddress_);
    }

    function contractId() external pure override returns (bytes32) {
        return keccak256('token-linker');
    }

    function gateway() public view override returns (IAxelarGateway) {
        return IAxelarGateway(gatewayAddress);
    }

    function sendToken(
        string memory destinationChain,
        address to,
        uint256 amount
    ) external payable {
        _takeToken(msg.sender, amount);
        string memory thisAddress = address(this).toString();
        bytes memory payload = abi.encode(to, amount);
        uint256 gasValue = _lockNative() ? msg.value - amount : msg.value;
        if (gasValue > 0) {
            gasService.payNativeGasForContractCall{ value: gasValue }(address(this), destinationChain, thisAddress, payload, msg.sender);
        }
        gateway().callContract(destinationChain, address(this).toString(), payload);
    }

    function _execute(
        string calldata, /*sourceChain*/
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        if (sourceAddress.toAddress() != address(this)) return;
        (address recipient, uint256 amount) = abi.decode(payload, (address, uint256));
        _giveToken(recipient, amount);
    }

    function _lockNative() internal pure virtual returns (bool) {
        return false;
    }

    function _giveToken(address to, uint256 amount) internal virtual;

    function _takeToken(address from, uint256 amount) internal virtual;
}

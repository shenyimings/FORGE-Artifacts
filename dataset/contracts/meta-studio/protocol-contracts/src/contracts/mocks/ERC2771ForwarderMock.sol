// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

/// @title Mock class using IERC2771Upgradeable
/// @dev Simple minimal forwarder to be used together with an ERC2771 compatible contract. See {ERC2771Context}.
contract ERC2771ForwarderMock {
    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
    }

    mapping(address => uint256) private _nonces;

    /// @dev Get nonce implementation
    /// @param from addresswhere to get the Nonce
    /// @return a number representing the nonce
    function getNonce(address from) public view returns (uint256) {
        return _nonces[from];
    }

    event Forwarded(bool, bytes);

    /// @notice dd
    /// @dev Execute forwarding request implementation
    /// @param req the forwarder request
    /// @return boolean and bytes data

    function execute(ForwardRequest calldata req) public returns (bool, bytes memory) {
        _nonces[req.from] = req.nonce + 1;

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = req.to.call{gas: req.gas, value: req.value}(
            abi.encodePacked(req.data, req.from)
        );

        if (success) {
            emit Forwarded(success, returndata);
            return (success, returndata);
        } else {
            emit Forwarded(success, returndata);
            string memory _revertMsg = _getRevertMsg(returndata);
            revert(_revertMsg);
        }
    }

    /// @dev https://ethereum.stackexchange.com/a/83577/61294
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}

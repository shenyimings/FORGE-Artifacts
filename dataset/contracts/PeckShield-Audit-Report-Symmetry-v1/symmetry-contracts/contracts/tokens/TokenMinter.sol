// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "../interfaces/ITradingFeeCoupon.sol";
import "../interfaces/ISYM.sol";
import "../utils/Initializable.sol";

contract TokenMinter is AccessControlEnumerable, Initializable {
    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    function initialize(address _admin) external onlyInitializeOnce {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function batchMintCoupon(
        address _token,
        address[] memory _tos,
        uint[] memory _values
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ITradingFeeCoupon token = ITradingFeeCoupon(_token);
        uint len = _tos.length;
        for (uint i = 0; i < len; ++i) {
            token.mintCoupon(
                _tos[i],
                _values[i],
                uint(keccak256(abi.encodePacked(blockhash(block.number - 1), _tos[i], "airdrop")))
            );
        }
    }

    function batchMintERC20(
        address _token,
        address[] memory _tos,
        uint[] memory _values
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ISYM token = ISYM(_token);
        uint len = _tos.length;
        for (uint i = 0; i < len; ++i) {
            token.mint(_tos[i], _values[i]);
        }
    }
}

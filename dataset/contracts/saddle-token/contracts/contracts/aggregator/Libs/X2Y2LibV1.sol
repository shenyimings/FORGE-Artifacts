// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "./X2Y2/structs.sol";

interface IX2Y2 {
    function run(
        RunInput memory input
    ) external;
}

error InvalidChain();

library X2Y2LibV1 {
    function _run(
        RunInput memory _input,
        uint256 _msgValue,
        address asset,
        uint256 tokenId,
        bool _revertIfTrxFails
    ) external {
        bytes memory _data = abi.encodeWithSelector(
            IX2Y2.run.selector,
            _input
        );

        address X2Y2;
        if (block.chainid == 1) {
            // mainnet
            X2Y2 = 0x74312363e45DCaBA76c59ec49a7Aa8A65a67EeD3;
        } else if (block.chainid == 5 || block.chainid == 31337) {
            X2Y2 = 0x1891EcD5F7b1E751151d857265D6e6D08ae8989e;
        } else {
            revert InvalidChain();
        }

        (bool success, ) = X2Y2.call{ value: _msgValue }(_data);

        if (!success && _revertIfTrxFails) {
            // Copy revert reason from call
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        // return back nft
        (bool success2, ) = asset.call(abi.encodeWithSelector(0x23b872dd, address(this), msg.sender, tokenId));

        if (!success2 && _revertIfTrxFails) {
            // Copy revert reason from call
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

    }
}

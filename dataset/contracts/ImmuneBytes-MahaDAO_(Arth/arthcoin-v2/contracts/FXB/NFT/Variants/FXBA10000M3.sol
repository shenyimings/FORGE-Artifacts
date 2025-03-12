// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import '../ArthBond_NFT.sol';

contract ARTHBA10000M3 is ArthBond_NFT {
    constructor(
        address _controller_address,
        address _timelock_address,
        string memory _series,
        uint256 _face_value,
        uint256 _maturity_months,
        uint256 _discount,
        uint256 _min_early_redeem_secs,
        uint256 _max_early_redemption_penalty_pct
    )
        ArthBond_NFT(
            _controller_address,
            _timelock_address,
            _series,
            _face_value,
            _maturity_months,
            _discount,
            _min_early_redeem_secs,
            _max_early_redemption_penalty_pct
        )
    {}
}

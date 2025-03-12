// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.0;

// import './ArthPoolvAMM.sol';

// contract PoolvAMM_USDC is ArthPoolvAMM {
//     address public USDC_address;

//     constructor(
//         address _arth_contract_address,
//         address _arthx_contract_address,
//         address _collateralAddress,
//         address _creator_address,
//         address _timelock_address,
//         address _uniswap_factory_address,
//         address _arthx_usdc_oracle_addr,
//         uint256 _pool_ceiling
//     )
//         ArthPoolvAMM(
//             _arth_contract_address,
//             _arthx_contract_address,
//             _collateralAddress,
//             _creator_address,
//             _timelock_address,
//             _uniswap_factory_address,
//             _arthx_usdc_oracle_addr,
//             _pool_ceiling
//         )
//     {
//         _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
//         USDC_address = _collateralAddress;
//     }
// }

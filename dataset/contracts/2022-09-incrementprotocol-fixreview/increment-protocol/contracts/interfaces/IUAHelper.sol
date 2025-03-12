// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

// contracts
import {ERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

// interfaces
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IUA} from "../interfaces/IUA.sol";
import {IClearingHouse} from "../interfaces/IClearingHouse.sol";

interface IUAHelper {
    function ua() external view returns (IUA);
    function clearingHouse() external view returns (IClearingHouse);
    function depositReserveToken(IERC20Metadata token, uint256 amount) external;
    function depositReserveToken(ERC20Permit token, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function withdrawReserveToken(IERC20Metadata token, uint256 amount) external;
}

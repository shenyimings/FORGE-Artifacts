// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC721Gateway.sol";
import "./IERC1155Gateway.sol";
import "./IERC20Gateway.sol";

interface IGateway is IERC721Gateway, IERC1155Gateway, IERC20Gateway {
    function operatorWhitelist(address _operator) external view returns (bool);

    function setManagerOf(address _nftContract, address _manager) external;

    function nftManager(address _nftContract) external view returns (address);

    function pause(address _contract) external;

    function unpause(address _contract) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface ITraderJoeLBPair {
    function tokenX() external returns (address);

    function tokenY() external returns (address);

    function balanceOf(address account, uint256 id)
        external
        view
        returns (uint256);

    function setApprovalForAll(address sender, bool approved) external;

    function totalSupply(uint256 id) external view returns (uint256);

    function collectFees(address account, uint256[] calldata ids)
        external
        returns (uint256 amountX, uint256 amountY);

    function getBin(uint24 id)
        external
        view
        returns (uint256 reserveX, uint256 reserveY);

    function getReservesAndId()
        external
        view
        returns (
            uint256 reserveX,
            uint256 reserveY,
            uint256 activeId
        );
}

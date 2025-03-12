// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

interface IFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function owner() external view returns (address);

    function buyback() external view returns (address);

    function money() external view returns (address);

    function migrator() external view returns (address);

    function swapFee() external view returns (uint256);

    function buybackShare() external view returns (uint256);

    function discountEligibilityBalance() external view returns (uint256);

    function lpFeeOn() external view returns (bool);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function toggleLpFee() external;

    function setOwner(address) external;

    function setMigrator(address) external;

    function setBuyback(address _buyback) external;

    function setMoney(address _money) external;

    function setSwapFee(uint256 _swapFee) external;

    function setBuybackShare(uint256 _buybackShare) external;

    function setDiscountEligibilityBalance(uint256 _discountEligibilityBalance)
        external;

    function getSwapFee(address _user) external view returns (uint256, uint256);

    function pairCodeHash() external pure returns (bytes32);
}

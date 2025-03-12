pragma solidity 0.5.12;

// 0x398eC7346DcD622eDc5ae82352F02bE94C62d119
interface LendingPool {
    function deposit(
        address _reserve,
        uint256 _amount,
        uint16 _referralCode
    ) external payable;
}

interface AToken {
    function balanceOf(address _user) external view returns (uint256);

    function principalBalanceOf(address _user) external view returns (uint256);

    function redeem(uint256 _amount) external;
}

// 0x3dfd23A6c5E8BbcFc9581d2E864a68feb6a076d3
interface LendingPoolCore {
    function getReserveATokenAddress(address _reserve)
        external
        view
        returns (address);

    function getReserveAvailableLiquidity(address _reserve)
        external
        view
        returns (uint256);
}

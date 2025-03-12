pragma solidity 0.5.12;

interface ILendFMe {
    function supply(address _token, uint256 _amount) external returns (uint256);

    function withdraw(address _token, uint256 _amount)
        external
        returns (uint256);

    function getSupplyBalance(address _user, address _token)
        external
        view
        returns (uint256);

    function markets(address _token)
        external
        view
        returns (
            bool,
            uint256,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        );

    // struct Balance {
    //     uint principal;
    //     uint interestIndex;
    // }

    function supplyBalances(address account, address token)
        external
        view
        returns (uint256, uint256);

    // mapping(address => mapping(address => Balance)) public supplyBalances;
}

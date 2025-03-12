// SPDX-License-Identifier: ISC
pragma solidity ^0.8.13;

interface ISCompVault {
    function balance() external view returns (uint256);

    function setMin(uint256 _min) external;

    function setGovernance(address _governance) external;

    function setController(address _controller) external;

    function available() external view returns (uint256);

    function earn() external;

    function depositAll() external returns (uint);

    function deposit(uint256 _amount) external returns (uint);

    function depositAllFor(address _receiver) external returns (uint);

    function depositFor(
        uint256 _amount,
        address _receiver
    ) external returns (uint);

    function withdrawAll() external returns (uint);

    function withdraw(uint256 _shares) external returns (uint);

    function withdrawAllFor(address _receiver) external returns (uint);

    function withdrawFor(
        uint256 _shares,
        address _receiver
    ) external returns (uint);

    function withdrawOneClick(
        uint256 _shares,
        address _receiver
    ) external returns (uint);
 
    function harvest(address reserve, uint256 amount) external;

    function getPricePerFullShare() external view returns (uint256);

    function totalSupply() external view returns (uint256);
}

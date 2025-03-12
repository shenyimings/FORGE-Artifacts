//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IYESVault {
    event Airdrop(address beneficiary, uint256 amount);
    event Deposit(address sender, uint256 amount);
    event Withdraw(address sender, uint256 amount);

    function tokensOf(address account) external view returns (uint256);

    function depositOf(address account) external view returns (uint256);

    function airdropOf(address account) external view returns (uint256);

    function releasedTo(address account) external view returns (uint256);

    function controller() external view returns (address);

    function yesToken() external view returns (address);

    function marketImpl() external view returns (address);

    function market() external view returns (address);

    function slippageTolerrance() external view returns (uint256);

    function totalAllocated() external view returns (uint256);

    function airdrop(address beneficiary, uint256 amount) external;

    function deposit(uint256 amount) external;

    function depositBKNext(uint256 amount, address _bitkubnext) external;

    function withdraw(uint256 amount) external;

    function withdrawBKNext(uint256 amount, address _bitkubnext) external;

    function sellMarket(address borrower, uint256 amount)
        external
        payable
        returns (uint256);

    /*** Admin Events ***/

    event NewController(address oldController, address newController);
    event NewYESToken(address oldYESToken, address newYESToken);
    event NewMarketImpl(address oldMarketImpl, address newMarketImpl);
    event NewMarket(address oldMarket, address newMarket);
    event NewSlippageTolerrance(uint256 oldTolerrance, uint256 newTolerrance);

    /*** Admin Functions ***/

    function _setController(address newController) external;

    function _setYESToken(address newYESToken) external;

    function _setMarketImpl(address newMarketImpl) external;

    function _setMarket(address newMarket) external;

    function _setSlippageTolerrance(uint256 newTolerrance) external;
}

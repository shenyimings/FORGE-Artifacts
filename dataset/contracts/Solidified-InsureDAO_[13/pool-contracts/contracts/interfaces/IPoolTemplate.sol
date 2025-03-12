pragma solidity ^0.6.0;

abstract contract IPoolTemplate {
    function allocateCredit(uint256 _credit)
        external
        virtual
        returns (uint256 _mintAmount);

    function allocatedCredit(address _index)
        external
        view
        virtual
        returns (uint256);

    function withdrawCredit(uint256 _credit)
        external
        virtual
        returns (uint256 _retVal);

    function availableBalance() public view virtual returns (uint256 _balance);

    function utilizationRate() public view virtual returns (uint256 _rate);

    function valueOfUnderlying(address _owner)
        public
        view
        virtual
        returns (uint256);

    function pendingPremium(address _index)
        external
        view
        virtual
        returns (uint256);
}

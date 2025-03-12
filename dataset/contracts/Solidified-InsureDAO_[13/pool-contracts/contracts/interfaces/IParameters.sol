pragma solidity ^0.6.0;

abstract contract IParameters {
    function commit_transfer_ownership(address _owner) external virtual;

    function apply_transfer_ownership() external virtual;

    function setVault(address _token, address _vault) external virtual;

    function setLockup(address _address, uint256 _target) external virtual;

    function setGrace(address _address, uint256 _target) external virtual;

    function setMindate(address _address, uint256 _target) external virtual;

    function setPremium2(address _address, uint256 _target) external virtual;

    function setFee2(address _address, uint256 _target) external virtual;

    function setWithdrawable(address _address, uint256 _target)
        external
        virtual;

    function setPremiumModel(address _address, address _target)
        external
        virtual;

    function setFeeModel(address _address, address _target) external virtual;

    function setCondition(bytes32 _reference, bytes32 _target) external virtual;

    function getVault(address _token) external view virtual returns (address);

    function getPremium(
        uint256 _amount,
        uint256 _term,
        uint256 _totalLiquidity,
        uint256 _lockedAmount,
        address _target
    ) external view virtual returns (uint256);

    function getFee(uint256 _amount, address _target)
        external
        view
        virtual
        returns (uint256);

    function getLockup(address _target) external view virtual returns (uint256);

    function getWithdrawable(address _target)
        external
        view
        virtual
        returns (uint256);

    function getGrace(address _target) external view virtual returns (uint256);

    function get_owner() public view virtual returns (address);

    function isOwner() public view virtual returns (bool);

    function getMin(address _target) external view virtual returns (uint256);

    function getFee2(uint256 _amoun, address _targett)
        external
        view
        virtual
        returns (uint256);

    function getPremium2(uint256 _amount, address _target)
        external
        view
        virtual
        returns (uint256);

    function getCondition(bytes32 _reference)
        external
        view
        virtual
        returns (bytes32);
}

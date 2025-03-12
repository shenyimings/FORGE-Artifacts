// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../libs/GluwacoinModel.sol";

import "./Validate.sol";

/**
 * @dev Extension of {ERC20} that allows users to escrow a transfer. When the fund is reserved, the sender designates
 * an `executor` of the `reserve`. The `executor` can `release` the fund to the pre-defined `recipient` and collect
 * a `fee`. If the `reserve` gets expired without getting executed, the `sender` or the `executor` can `reclaim`
 * the fund back to the `sender`.
 */
abstract contract ERC20Reservable is Initializable, ERC20Upgradeable {
    using AddressUpgradeable for address;

    enum ReservationStatus {
        Draft,
        Active,
        Reclaimed,
        Completed
    }

    struct Reservation {
        uint256 _amount;
        uint256 _fee;
        address _recipient;
        address _executor;
        uint256 _expiryBlockNum;
        ReservationStatus _status;
    }

    // Address mapping to mapping of nonce to amount and expiry for that nonce.
    mapping (address => mapping(uint256 => Reservation)) private _reserved;

    // Total amount of reserved balance for address
    mapping (address => uint256) private _totalReserved;

    function __ERC20Reservable_init(string memory name, string memory symbol) internal
    initializer {
        __ERC20_init_unchained(name, symbol);
        __ERC20Reservable_init_unchained();
    }

    function __ERC20Reservable_init_unchained() internal initializer {
    }

    function getReservation(address sender, uint256 nonce) external view
        returns (
            uint256 amount,
            uint256 fee,
            address recipient,
            address executor,
            uint256 expiryBlockNum,
            ReservationStatus status
        )
    {
        
        Reservation storage reservation = _reserved[sender][nonce];

        amount = reservation._amount;
        fee = reservation._fee;
        recipient = reservation._recipient;
        executor = reservation._executor;
        expiryBlockNum = reservation._expiryBlockNum;      
        status = reservation._status;
    }

    function reservedBalanceOf(address account) external view returns (uint256 amount) {
        return balanceOf(account) - _unreservedBalance(account);
    }

    function unreservedBalanceOf(address account) external view returns (uint256 amount) {
        return _unreservedBalance(account);
    }

    function reserve(
        address sender,
        address recipient,
        address executor,
        uint256 amount,
        uint256 fee,
        uint256 nonce,
        uint256 expiryBlockNum,
        bytes calldata sig
    )
        external returns (bool success)
    {
        require(_reserved[sender][nonce]._expiryBlockNum == 0, "ERC20Reservable: the sender used the nonce already");

        require(expiryBlockNum > block.number, "ERC20Reservable: invalid block expiry number");
        require(executor != address(0), "ERC20Reservable: cannot execute from zero address");

        uint256 total = amount + fee;
        require(_unreservedBalance(sender) >= total, "ERC20Reservable: insufficient unreserved balance");

        bytes32 hash = keccak256(abi.encodePacked(GluwacoinModel.SigDomain.Reserve, block.chainid, address(this), sender, recipient, executor, amount, fee, nonce, expiryBlockNum));
        Validate.validateSignature(hash, sender, sig);

        _reserved[sender][nonce] = Reservation(amount, fee, recipient, executor, expiryBlockNum,
            ReservationStatus.Active);
        _totalReserved[sender] = _totalReserved[sender] + total;

        return true;
    }

    function execute(address sender, uint256 nonce) external returns (bool success) {
        Reservation storage reservation = _reserved[sender][nonce];

        require(reservation._expiryBlockNum != 0, "ERC20Reservable: reservation does not exist");
        require(_msgSender() == sender || _msgSender() == reservation._executor,
            "ERC20Reservable: this address is not authorized to execute this reservation");
        require(reservation._expiryBlockNum > block.number,
            "ERC20Reservable: reservation has expired and cannot be executed");
        require(reservation._status == ReservationStatus.Active,
            "ERC20Reservable: invalid reservation status to execute");

        address executor = reservation._executor;
        address recipient = reservation._recipient;
        uint256 fee = reservation._fee;
        uint256 amount = reservation._amount;
        uint256 total = amount + fee;

        _reserved[sender][nonce]._status = ReservationStatus.Completed;
        _totalReserved[sender] = _totalReserved[sender] - total;

        _transfer(sender, executor, fee);
        _transfer(sender, recipient, amount);

        return true;
    }

    function reclaim(address sender, uint256 nonce) external returns (bool success) {
        Reservation storage reservation = _reserved[sender][nonce];

        require(reservation._expiryBlockNum != 0, "ERC20Reservable: reservation does not exist");
        require(_msgSender() == sender || _msgSender() == reservation._executor,
            "ERC20Reservable: only the sender or the executor can reclaim the reservation back to the sender");
        require(reservation._expiryBlockNum <= block.number || _msgSender() == reservation._executor,
            "ERC20Reservable: reservation has not expired or you are not the executor and cannot be reclaimed");
        require(reservation._status == ReservationStatus.Active,
            "ERC20Reservable: invalid reservation status to reclaim");

        _reserved[sender][nonce]._status = ReservationStatus.Reclaimed;
        _totalReserved[sender] = _totalReserved[sender] - reservation._amount - reservation._fee;

        return true;
    }

    function _unreservedBalance(address sender) internal view returns (uint256 amount) {
        return balanceOf(sender) - _totalReserved[sender];
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override (ERC20Upgradeable) {
        if (from != address(0)) {
            require(_unreservedBalance(from) >= amount, "ERC20Reservable: transfer amount exceeds unreserved balance");
        }

        super._beforeTokenTransfer(from, to, amount);
    }

    uint256[50] private __gap;
}
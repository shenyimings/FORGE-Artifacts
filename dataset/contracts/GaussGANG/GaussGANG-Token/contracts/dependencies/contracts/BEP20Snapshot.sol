// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
import "./BEP20.sol";
import "../access/Ownable.sol";
import "../libraries/Arrays.sol";
import "../libraries/Counters.sol";



/*  This contract extends an BEP20 token with a snapshot mechanism. When a snapshot is created, the balances and total supply at the time are recorded for later access.
        
        - Snapshots are created by the internal {_snapshot} function, which will emit the {Snapshot} event and return a
            snapshot id. To get the total supply at the time of a snapshot, call the function {totalSupplyAt} with the snapshot
            id. To get the balance of an account at the time of a snapshot, call the {balanceOfAt} function with the snapshot id
            and the account address.
*/
abstract contract BEP20Snapshot is BEP20 {

    using Arrays for uint256[];
    using Counters for Counters.Counter;    

    /* Snapshotted values have arrays of ids and the value corresponding to that id. 
        - These could be an array of a Snapshot struct, but that would impede usage of functions that work on an array. */
    struct Snapshots {
        uint256[] ids;
        uint256[] values;
    }
    
    mapping(address => Snapshots) private _accountBalanceSnapshots;
    Snapshots private _totalSupplySnapshots;
    
    // Snapshot ids increase monotonically, with the first value being 1. An id of 0 is invalid.
    Counters.Counter private _currentSnapshotId;
    
    // Emitted by {_snapshot} when a snapshot identified by `id` is created.
    event Snapshot(uint256 id);
    

    // Initializes BEP20Snapshot contract
    function __BEP20Snapshot_init() internal initializer {
        __Context_init_unchained();
        __BEP20Snapshot_init_unchained();
    }
    
    
    // Initializes BEP20Snapshot contract
    function __BEP20Snapshot_init_unchained() internal initializer {}


    // Creates a new snapshot and returns its snapshot id. Emits a {Snapshot} event that contains the same id.
    function _snapshot() internal virtual returns (uint256) {
        _currentSnapshotId.increment();

        uint256 currentId = _getCurrentSnapshotId();
        emit Snapshot(currentId);
        return currentId;
    }


    // Get the current snapshotId.
    function _getCurrentSnapshotId() internal view virtual returns (uint256) {
        return _currentSnapshotId.current();
    }


    // Retrieves the balance of `account` at the time `snapshotId` was created.
    function balanceOfAt(address account, uint256 snapshotId) public view virtual returns (uint256) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _accountBalanceSnapshots[account]);

        return snapshotted ? value : balanceOf(account);
    }


    // Retrieves the total supply at the time `snapshotId` was created.
    function totalSupplyAt(uint256 snapshotId) public view virtual returns (uint256) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _totalSupplySnapshots);

        return snapshotted ? value : totalSupply();
    }


    // Update balance and/or total supply snapshots before the values are modified. This is implemented
    // in the _beforeTokenTransfer hook, which is executed for _mint, _burn, and _transfer operations.
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) {
            // mint
            _updateAccountSnapshot(to);
            _updateTotalSupplySnapshot();
        } else if (to == address(0)) {
            // burn
            _updateAccountSnapshot(from);
            _updateTotalSupplySnapshot();
        } else {
            // transfer
            _updateAccountSnapshot(from);
            _updateAccountSnapshot(to);
        }
    }
    
    
    // Returns the value held in the snapshot using the id as an identifier.
    function _valueAt(uint256 snapshotId, Snapshots storage snapshots) private view returns (bool, uint256) {
        require(snapshotId > 0, "BEP20Snapshot: id is 0");
        require(snapshotId <= _getCurrentSnapshotId(), "BEP20Snapshot: nonexistent id");

        /*  When a valid snapshot is queried, there are three possibilities:
                a) The queried value was not modified after the snapshot was taken. Therefore, a snapshot entry was never created for this id,
                    and all stored snapshot ids are smaller than the requested one. The value that corresponds to this id is the current one.
                
                b) The queried value was modified after the snapshot was taken. Therefore, there will be an entry with the
                    requested id, and its value is the one to return.
        
                c) More snapshots were created after the requested one, and the queried value was later modified. There will be no entry for the requested id:
                        - the value that corresponds to it is that of the smallest snapshot id that is larger than the requested one.
            
            In summary, we need to find an element in an array, returning the index of the smallest value that is larger if it is not found,
              unless said value doesn't exist (e.g. when all values are smaller).
                    - Arrays.findUpperBound does exactly this. */
        uint256 index = snapshots.ids.findUpperBound(snapshotId);

        if (index == snapshots.ids.length) {
            return (false, 0);
        } 
        
        else {
            return (true, snapshots.values[index]);
        }
    }
    
    
    // Internal function, updates the balance of passed "account" before values are modified.
    function _updateAccountSnapshot(address account) private {
        _updateSnapshot(_accountBalanceSnapshots[account], balanceOf(account));
    }


    // Internal function, updates the "totalSupply" of token before values are modified.
    function _updateTotalSupplySnapshot() private {
        _updateSnapshot(_totalSupplySnapshots, totalSupply());
    }

    
    // Internal function, updates snapshot with either the new balances, or new totalSupply.
    function _updateSnapshot(Snapshots storage snapshots, uint256 currentValue) private {
        uint256 currentId = _getCurrentSnapshotId();
        
        if (_lastSnapshotId(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(currentValue);
        }
    }
    
    
    // Returns the last snapshot id.
    function _lastSnapshotId(uint256[] storage ids) private view returns (uint256) {
        if (ids.length == 0) {
            return 0;
        } 
        
        else {
            return ids[ids.length - 1];
        }
    }
    
    uint256[46] private __gap;
}
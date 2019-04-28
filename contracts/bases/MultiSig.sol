pragma solidity >=0.4.24 <0.5.0;

import "../open-zeppelin/SafeMath.sol";

/** @title MultiSignature, MultiOwner Controls */
contract MultiSig {

	using SafeMath32 for uint32;

	struct Address {
		bytes32 id;
		bool restricted;
	}

	struct Authority {
		mapping (bytes4 => bool) signatures;
		mapping (bytes32 => address[]) multiSigAuth;
		uint32 multiSigThreshold;
		uint32 addressCount;
		uint32 approvedUntil;
	}

	bytes32 public ownerID;
	mapping (address => Address) idMap;
	mapping (bytes32 => Authority) authorityData;

	event MultiSigCall (
		bytes32 indexed id,
		bytes4 indexed callSignature,
		bytes32 indexed callHash,
		address caller,
		uint256 callCount,
		uint256 threshold
	);
	event MultiSigCallApproved (
		bytes32 indexed id,
		bytes4 indexed callSignature,
		bytes32 indexed callHash,
		address caller
	);
	event NewAuthority (
		bytes32 indexed id,
		uint32 approvedUntil,
		uint32 threshold
	);
	event NewAuthorityAddresses (
		bytes32 indexed id,
		address[] added,
		uint32 ownerCount
	);
	event RemovedAuthorityAddresses (
		bytes32 indexed id,
		address[] removed,
		uint32 ownerCount
	);
	event ApprovedUntilSet (bytes32 indexed id, uint32 approvedUntil);
	event ThresholdSet (bytes32 indexed id, uint32 threshold);
	event NewAuthorityPermissions (bytes32 indexed id, bytes4[] signatures);
	event RemovedAuthorityPermissions (bytes32 indexed id, bytes4[] signatures);

	/**
		@notice KYC registrar constructor
		@param _owners Array of addresses for owning authority
		@param _threshold multisig threshold for owning authority
	 */ 
	constructor(address[] _owners, uint32 _threshold) public {
		require(_owners.length > 0);
		require (_threshold > 0);
		ownerID = keccak256(abi.encodePacked(address(this)));
		Authority storage a = authorityData[ownerID];
		a.addressCount = _addAddresses(ownerID, _owners);
		require(a.addressCount >= _threshold);
		a.multiSigThreshold = _threshold;
		emit NewAuthority(ownerID, a.approvedUntil, _threshold);
	}

	/** @dev Checks that the calling address is associated with the owner */
	function _onlyOwner() internal view {
		require(idMap[msg.sender].id == ownerID);
		require(!idMap[msg.sender].restricted);
	}

	/**
		@dev
	 		Checks that the calling address belongs to the owner, or is
			associated with the authority it is trying to enact a change upon.
	 */
	function _onlySelfAuthority(bytes32 _id) internal view {
		require (_id != 0);
		if (idMap[msg.sender].id != ownerID) {
			require(idMap[msg.sender].id == _id, "dev: wrong authority");
		}
	}

	/**
		@notice Internal function to add new addresses
		@param _id investor or authority ID
		@param _addr array of addresses
		@return number of new addresses (not previous restricted)
	 */
	function _addAddresses(
		bytes32 _id,
		address[] _addr
	)
		internal
		returns (uint32 _count) 
	{
		for (uint256 i; i < _addr.length; i++) {
			if (idMap[_addr[i]].id == _id && idMap[_addr[i]].restricted) {
				idMap[_addr[i]].restricted = false;
			} else if (idMap[_addr[i]].id == 0) {
				idMap[_addr[i]].id = _id;
			} else {
				revert("dev: known address");
			}
		}
		_count = uint32(_addr.length);
		emit NewAuthorityAddresses(
			_id,
			_addr,
			authorityData[_id].addressCount.add(_count)
		);
		return uint32(_count);
	}

	/**
		@notice Internal multisig functionality
		@dev
			Includiding a call to this function will also restrict
			the calling function so that only an authority may use it.
			It is comparble to using an 'onlyAuthority' modifier.
		@return bool - has call met multisig threshold?
	 */
	function _checkMultiSig() internal returns (bool) {
		return _multiSigPrivate(
			idMap[msg.sender].id,
			msg.sig,
			keccak256(msg.data),
			msg.sender
		);
	}

	/**
		@notice External multisig functionality
		@dev This call allows you to add multisig functionality to modules.
		@param _caller Address of caller
		@param _callHash keccack256 of original msg.calldata
		@param _sig original msg.sig
		@return bool - has call met multisig threshold?
	 */
	function checkMultiSigExternal(
		address _caller,
		bytes32 _callHash,
		bytes4 _sig
	)
		external
		returns (bool)
	{
		return _multiSigPrivate(
			idMap[_caller].id,
			_sig,
			keccak256(abi.encodePacked(_callHash, _sig, msg.sender)),
			_caller
		);
	}

	/**
		@notice Private multisig functionality
		@dev common logic for _checkMultiSig() and checkMultiSigExternal()
		@param _id calling authority ID
		@param _sig original msg.sig
		@param _callHash keccack256 of msg.callhash
		@param _sender caller address
		@return bool - has call met multisig threshold?
	 */
	function _multiSigPrivate(
		bytes32 _id,
		bytes4 _sig,
		bytes32 _callHash,
		address _sender
	)
		private
		returns (bool)
	{
		require(!idMap[_sender].restricted);
		if (_id != ownerID) {
			require(authorityData[_id].signatures[_sig], "dev: not permitted");
			require(authorityData[_id].approvedUntil >= now, "dev: expired");
		}
		Authority storage a = authorityData[_id];
		for (uint256 i; i < a.multiSigAuth[_callHash].length; i++) {
			require(a.multiSigAuth[_callHash][i] != _sender, "dev: repeat caller");
		}
		if (a.multiSigAuth[_callHash].length + 1 >= a.multiSigThreshold) {
			delete a.multiSigAuth[_callHash];
			emit MultiSigCallApproved(_id, _sig, _callHash, _sender);
			return true;
		}
		a.multiSigAuth[_callHash].push(_sender);
		emit MultiSigCall(
			_id, 
			_sig,
			_callHash,
			_sender,
			a.multiSigAuth[_callHash].length,
			a.multiSigThreshold
		);
		return false;
	}

	/**
		@notice External view to fetch an authority ID from an address
		@param _addr authority address
		@return bytes32 authority ID
	 */
	function getID(address _addr) external view returns (bytes32) {
		return idMap[_addr].id;
	}

	/**
		@notice External view to fetch authority information from an ID
		@param _id authority ID
		@return authority address count, threshold, approved until
	 */
	function getAuthority(
		bytes32 _id
	)
		external
		view
		returns (
			uint32 _addressCount,
			uint32 _threshold,
			uint32 _approvedUntil
		)
	{
		Authority storage a = authorityData[_id];
		require (a.addressCount > 0);
		return (a.addressCount, a.multiSigThreshold, a.approvedUntil);
	}

	/**
		@notice Check if address belongs to an authority
		@param _addr authority address
		@return boolean
	 */
	function isAuthority(address _addr) external view returns (bool) {
		return authorityData[idMap[_addr].id].addressCount > 0;
	}

	/**
		@notice Check if ID belongs to an authority
		@param _id authority ID
		@return boolean
	 */
	function isAuthorityID(bytes32 _id) external view returns (bool) {
		return authorityData[_id].addressCount > 0;
	}

	/**
		@notice Check if address belongs to an approved authority
		@dev Used to verify permission for calls to modules
		@param _addr Address of caller
		@param _sig Original msg.sig
		@return bool approval
	 */
	function isApprovedAuthority(
		address _addr,
		bytes4 _sig
	)
		external
		view
		returns (bool)
	{
		
		if (idMap[_addr].restricted) return false;
		bytes32 _id = idMap[_addr].id;
		if (_id == ownerID) return true;
		return (
			authorityData[_id].signatures[_sig] &&
			authorityData[_id].approvedUntil >= now
		);
	}

	/**
		@notice Add a new authority
		@param _addr Array of addressses to register as authority
		@param _signatures Array of bytes4 sigs this authority may call
		@param _approvedUntil Epoch time that authority is approved until
		@param _threshold Minimum number of calls to a method for multisig
		@return bool success
	 */
	function addAuthority(
		address[] _addr,
		bytes4[] _signatures,
		uint32 _approvedUntil,
		uint32 _threshold
	)
		public
		returns (bool)
	{
		_onlyOwner();
		if (!_checkMultiSig()) return false;
		require (_threshold > 0, "dev: threshold zero");
		bytes32 _id = keccak256(abi.encodePacked(_addr));
		Authority storage a = authorityData[_id];
		require(a.addressCount == 0, "dev: known authority");
		for (uint256 i; i < _signatures.length; i++) {
			a.signatures[_signatures[i]] = true;
		}
		a.approvedUntil = _approvedUntil;
		a.addressCount = _addAddresses(_id, _addr);
		require (a.addressCount >= _threshold, "dev: treshold > count");
		a.multiSigThreshold = _threshold;
		emit NewAuthority(_id, _threshold, _approvedUntil);
		emit NewAuthorityPermissions(_id, _signatures);
		return true;
	}

	/**
		@notice Modify an authority's approvedUntil time
		@dev You can restrict an authority by setting the value to 0
		@param _id Authority ID
		@param _approvedUntil Epoch time that authority is approved until
		@return bool success
	 */
	function setAuthorityApprovedUntil(
		bytes32 _id,
		uint32 _approvedUntil
	 )
	 	external
		returns (bool)
	{
		_onlyOwner();
		if (!_checkMultiSig()) return false;
		require(authorityData[_id].addressCount > 0, "dev: unknown ID");
		authorityData[_id].approvedUntil = _approvedUntil;
		emit ApprovedUntilSet(_id, _approvedUntil);
		return true;
	}

	/**
		@notice Modify an authority's permitted function calls
		@param _id Authority ID
		@param _signatures Array of bytes4 sigs
		@param _permitted bool permission for calling the signatures
		@return bool success
	 */
	function setAuthoritySignatures(
		bytes32 _id,
		bytes4[] _signatures,
		bool _permitted
	)
		external
		returns (bool)
	{
		_onlyOwner();
		if (!_checkMultiSig()) return false;
		Authority storage a = authorityData[_id];
		require(a.addressCount > 0);
		for (uint256 i; i < _signatures.length; i++) {
			a.signatures[_signatures[i]] = _permitted;
		}
		if (_permitted) {
			emit NewAuthorityPermissions(_id, _signatures);
		} else {
			emit RemovedAuthorityPermissions(_id, _signatures);
		}
		return true;
	}

	/**
		@notice Modify an authority's multisig threshold
		@param _id Authority ID
		@param _threshold New multisig threshold value
		@return bool success
	 */
	function setAuthorityThreshold(
		bytes32 _id,
		uint32 _threshold
	)
		external
		returns (bool)
	{
		_onlySelfAuthority(_id);
		if (!_checkMultiSig()) return false;
		require (_threshold > 0, "dev: threshold zero");
		Authority storage a = authorityData[_id];
		require(a.addressCount >= _threshold, "dev: threshold too high");
		a.multiSigThreshold = _threshold;
		emit ThresholdSet(_id, _threshold);
		return true;
	}

	/**
		@notice Add new addresses to an authority
		@param _id Authority ID
		@param _addr Array of addresses
		@return bool success
	 */
	function addAuthorityAddresses(
		bytes32 _id,
		address[] _addr
	)
		external
		returns (bool)
	{
		_onlySelfAuthority(_id);
		if (!_checkMultiSig()) return false;
		Authority storage a = authorityData[_id];
		require(a.addressCount > 0, "dev: unknown ID");
		a.addressCount = a.addressCount.add(_addAddresses(_id, _addr));
		return true;
	}

	/**
		@notice Remove addresses from an authority
		@dev Once an address has been removed it may never be re-used
		@param _id Authority ID
		@param _addr Array of addresses
		@return bool success
	 */
	function removeAuthorityAddresses(
		bytes32 _id,
		address[] _addr
	)
		external
		returns (bool)
	{
		_onlySelfAuthority(_id);
		if (!_checkMultiSig()) return false;
		Authority storage a = authorityData[_id];
		for (uint256 i; i < _addr.length; i++) {
			require(idMap[_addr[i]].id == _id, "dev: wrong ID");
			require(!idMap[_addr[i]].restricted, "dev: already restricted");
			idMap[_addr[i]].restricted = true;
		}
		a.addressCount = a.addressCount.sub(uint32(_addr.length));
		require (a.addressCount >= a.multiSigThreshold, "dev: count below threshold");
		emit RemovedAuthorityAddresses(_id, _addr, a.addressCount);
		return true;
	}

}

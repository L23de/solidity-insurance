pragma solidity >=0.7.0 <0.9.0;

contract InsurancePolicy {
    address private owner; // Insurance company's address
    mapping(address => uint256) premiums; // Balances of insurees and their premiums
    WeatherData private oracle;
    bool private lockBalances;
    uint256 payoutMax;

    // Uploads an event to the blockchain
    event Payout(address indexed holder, uint256 amount);

    // Only called once, when the contract is deployed
    // Set the contract's owner to the one who deployed it
    constructor() {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        oracle = WeatherData(0x2B717f348592895258741b02c72CCED7Acb8dd5D); // Set source of weather data to address provided
    }

    // Required so that the contract can receive either
    receive() external payable {}

    fallback() external payable {}

    // Called by owner (check sender == owner)
    // Transfers funds from owner to contract
    function deposit() public payable {
        require(
            msg.sender == owner,
            "Only the insurance company can deposit funds"
        );
    }

    // DEBUG: Gets the balance of the contract and worst case payout maximum
    // function getBalance() public view returns (uint256) {
    //     return address(this).balance;
    // }

    // function getPayoutMax() public view returns(uint256) {
    //     return payoutMax;
    // }

    // Called by addresses who want to create a policy with this contract
    // Argument should be the total policyAmount
    // Sender addresses should be charged 10% of policyAmount
    function createPolicy(uint256 policyAmount) public payable {
        require(!lockBalances);
        lockBalances = true;
        //fund[address(this)] += premium
        //fund(msg.sender) -= premium;
        address policyHolder = msg.sender;
        require(
            premiums[policyHolder] == 0,
            "Only one policy can be held per address"
        );
        uint256 premium = policyAmount / 10;
        require(
            msg.value == premium,
            "Please include exactly 10% of the policy amount in your request"
        );
        payoutMax += policyAmount;
        require(
            address(this).balance >= payoutMax,
            "The insurance company cannot handle this claim"
        );
        premiums[policyHolder] = premium;
        lockBalances = false;
    }

    // Used by both claimPolicy() and claimForUser()
    function claim() private {}

    // Called by address who are attempting to submit a claim
    // Check if sender is in premiums
    // Check if WeatherData.getRainfall() >= 50mm
    // If above checks out, send 10 x premiums[sender] to sender
    function claimPolicy() public {
        address policyHolder = msg.sender;
        require(
            premiums[policyHolder] != 0,
            "An existing policy for this address does not exist"
        );
        require(
            oracle.getRainfall() < 50,
            "Conditions have not been met for you to claim"
        );
        uint256 payout = premiums[policyHolder] * 10;
        (bool sent, bytes memory data) = policyHolder.call{value: payout}("");
        payoutMax -= payout;
        delete premiums[policyHolder];
        emit Payout(policyHolder, payout);
    }

    // Should function virtually the same as claimPolicy(), except the sender is claiming for toAddr
    function claimForUser(address payable toAddr) public {
        require(
            premiums[toAddr] != 0,
            "An existing policy for this address does not exist"
        );
        require(
            oracle.getRainfall() < 50,
            "Conditions have not been met for you to claim"
        );
        uint256 payout = premiums[toAddr] * 10;
        (bool sent, bytes memory data) = msg.sender.call{value: payout}("");
        payoutMax -= payout;
        delete premiums[toAddr];
        emit Payout(msg.sender, payout);
    }

    // Called by an existing insuree (check if in premiums) to exit their policy
    // Remove sender from premiums
    function cancelPolicy() public {
        address policyHolder = msg.sender;
        payoutMax -= premiums[policyHolder] * 10;
        delete premiums[policyHolder];
    }

    // Called by the owner (Check if sender == owner)
    // Closes the policy of address and refunds premiums[toAddr] to toAddr
    function closePolicy(address payable policyHolder) public {
        require(!lockBalances);
        lockBalances = true;
        require(
            msg.sender == owner,
            "Only the insurance company can close policy and refund premiums"
        );
        (bool sent, bytes memory data) = policyHolder.call{
            value: premiums[policyHolder]
        }("");
        payoutMax -= premiums[policyHolder] * 10;
        delete premiums[policyHolder];
        lockBalances = false;
    }

    // Called by the owner (check if sender == owner)
    // Check that payout won't cause overexposure
    // Transfer from this address to the owner's address
    function withdraw(uint256 payout) public {
        require(!lockBalances);
        lockBalances = true;
        require(msg.sender == owner, "Only the insurance company can withdraw");

        require(
            payoutMax <= address(this).balance,
            "Withdrawing more than your payout obligations can overexpose you to missing payouts"
        );
        (bool sent, bytes memory data) = owner.call{value: payout}("");
        lockBalances = false;
    }

    function deleteCompany() public {
        require(msg.sender == owner);
        selfdestruct(payable(owner));
    }
}

abstract contract WeatherData {
    function setRainfall(uint256 x) public virtual;

    function getRainfall() external view virtual returns (uint256);
}

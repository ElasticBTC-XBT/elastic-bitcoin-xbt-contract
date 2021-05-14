# Deploy XBN

- Sử dụng oz/cli để deploy contract:

```bash
npx oz deploy
```

- Chọn upgradable contract

![Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled.png](Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled.png)

- Chọn network là **mainnet**
- Chọn contract muốn deploy: XBN
- Chọn Yes để gọi hàm initialize khi deploy

![Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%201.png](Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%201.png)

- Điền đia chỉ owner

![Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%202.png](Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%202.png)

- Deploy thành công cho 3 địa chỉ, địa chỉ upgrade được là địa chỉ của AdminUpgradableProxy

## Upgrade XBN

- Sử dụng oz/cli để upgrade contract bằng lệnh:

    ```jsx
    npx oz upgrade
    ```

- Sau khi upgrade, **verify** và **publish** I*mplement Contract* vừa deploy
    - Flatten XBN thành 1 file để Submit trên bscscan

```bash
npx truffle-flattener ./contracts/xbn-protocol/XBN.sol > ./contracts/flatten-contracts/XBNFlat.sol
```

- Chọn các options sau khi **verify** và **publish** trên bscscan:

    ```bash
    - Compiler version: 0.6.8
    - Optimization: No
    - Lisence: No
    ```

- Copy contract đã flatten ở trên vào ô bên dưới

![Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%203.png](Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%203.png)

- Chọn **Verify and Publish**

![Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%204.png](Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%204.png)

### Set params cần thiết

1. Set B**urn Rate**: Tỉ lệ token được chuyển vào ví burn cho mỗi giao dịch
Ví dụ: 2 ⇒ 2%

![Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%205.png](Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%205.png)

2. Set B**urn Threshold: Số lượng token trong giao dịch để bắt đầu thu thuế** 

Ví dụ: 10 XBN ⇒ 10 * 10**18 ⇒ 10000000000000000000

([https://eth-converter.com/](https://eth-converter.com/)) 

![Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%206.png](Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%206.png)

3. Set **Burn Address: Set địa chỉ ví nhận số XBN được Burn: 0x000000000000000000000000000000000000dEaD**

![Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%207.png](Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%207.png)

- Set **Exception Address: Set các địa chỉ ví không thu thuế:**

![Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%208.png](Deploy%20XBN%203e28813f59fa424c9e69636adedfde6b/Untitled%208.png)
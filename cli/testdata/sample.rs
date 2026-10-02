use std::collections::HashMap;

fn main() {
    let mut counts: HashMap<&str, i32> = HashMap::new();
    for word in "a b a c b a".split_whitespace() {
        *counts.entry(word).or_insert(0) += 1;
    }
    println!("{:?}", counts);
}

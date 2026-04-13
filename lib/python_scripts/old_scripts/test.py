import os
from transformers import AutoTokenizer, pipeline
from optimum.onnxruntime import ORTModelForTokenClassification
import onnxruntime as ort

# Define model path and test sentences
model_path_quantised = "../../models/enriched_quantised/"
test_sentences = [
    "The patient was diagnosed with diabetes.",
    "Researchers found a strong correlation between smoking and lung cancer.",
    "The medication dosage should be carefully monitored to avoid side effects.",
    "Gene therapy has shown promise in treating rare genetic disorders."
]

# Function to load and test NER model with sample sentences
def test_ner_model_affinity_issues():
    # Set session options to control threading
    session_options = ort.SessionOptions()
    session_options.intra_op_num_threads = 1  # Limit to a single thread
    session_options.inter_op_num_threads = 1  # Limit to a single thread

    # Load model and tokenizer
    print("Loading NER model and tokenizer from " + model_path_quantised)
    model_quantized = ORTModelForTokenClassification.from_pretrained(
        model_path_quantised, file_name="model_quantized.onnx", session_options=session_options
    )
    tokenizer_quantized = AutoTokenizer.from_pretrained(
        model_path_quantised,
        model_max_length=512,
        batch_size=4,
        truncation=True
    )
    ner_quantized = pipeline(
        "token-classification",
        model=model_quantized,
        tokenizer=tokenizer_quantized,
        aggregation_strategy="max"
    )
    print("NER model and tokenizer loaded successfully.")

    # Test inference with sample sentences
    print("Running test inference on sample sentences...")
    results = ner_quantized(test_sentences)
    for i, result in enumerate(results):
        print(f"Sentence {i + 1}:")
        for entity in result:
            print(f" - Entity: {entity['word']}, Type: {entity['entity_group']}, Score: {entity['score']}")

# Main entry point
if __name__ == '__main__':
    test_ner_model_affinity_issues()

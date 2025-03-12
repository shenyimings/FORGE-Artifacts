import json
import click
from rich.console import Console
from rich.table import Table

console = Console()
DIMENSIONS = [
    "address",
    "chain",
    "url",
    "commit",
    "vuln_finding",
    "severity",
    "location",
]


def calculate_metrics(stats):
    """Calculate precision, recall and F1 score"""
    correct = stats["correct"]
    total_extracted = stats["total_extracted"]  # Total number extracted
    total_expected = stats["total_expected"]  # Total expected from ground truth

    precision = correct / total_extracted if total_extracted > 0 else 0
    recall = correct / total_expected if total_expected > 0 else 0
    f1 = (
        2 * (precision * recall) / (precision + recall)
        if (precision + recall) > 0
        else 0
    )

    return {"P": precision * 100, "R": recall * 100, "F": f1 * 100}


def aggregate_results(annotations):
    """Aggregate results across all dimensions"""
    dimensions = DIMENSIONS
    stats = {
        dim: {"total_extracted": 0, "correct": 0, "total_expected": 0}
        for dim in dimensions
    }

    for entry in annotations:
        for dim in dimensions:
            for metric in ["total_extracted", "correct", "total_expected"]:
                stats[dim][metric] += entry[dim][metric]

    # Calculate total
    total = {"total_extracted": 0, "correct": 0, "total_expected": 0}
    for dim in dimensions:
        for metric in ["total_extracted", "correct", "total_expected"]:
            total[metric] += stats[dim][metric]

    stats["TOTAL"] = total
    return stats


def calculate_macro_f1(stats):
    """Calculate macro-F1 score (average of F1 scores)"""
    dimensions = DIMENSIONS
    f1_scores = []

    for dim in dimensions:
        metrics = calculate_metrics(stats[dim])
        f1_scores.append(metrics["F"])

    return sum(f1_scores) / len(f1_scores)


def calculate_micro_f1(stats):
    """Calculate micro-F1 score (F1 of aggregated stats)"""
    return calculate_metrics(stats["TOTAL"])["F"]


def display_results(stats):
    """Display results in a rich table"""
    table = Table(title="Information Extraction Performance")

    table.add_column("Type", style="cyan")
    table.add_column("Extracted", justify="right")
    table.add_column("Correct", justify="right")
    table.add_column("Expected", justify="right")
    table.add_column("P(%)", justify="right")
    table.add_column("R(%)", justify="right")
    table.add_column("F(%)", justify="right")

    # Calculate averages excluding TOTAL
    p_values = []
    r_values = []
    f_values = []
    
    for dim in DIMENSIONS:
        metrics = calculate_metrics(stats[dim])
        p_values.append(metrics['P'])
        r_values.append(metrics['R'])
        f_values.append(metrics['F'])

    # Display all rows including TOTAL
    for dim in [*DIMENSIONS, "TOTAL"]:
        metrics = calculate_metrics(stats[dim])
        table.add_row(
            dim.upper(),
            str(stats[dim]["total_extracted"]),
            str(stats[dim]["correct"]),
            str(stats[dim]["total_expected"]),
            f"{metrics['P']:.1f}",
            f"{metrics['R']:.1f}",
            f"{metrics['F']:.1f}",
        )

    # Add Average row
    table.add_row(
        "AVERAGE",
        "",
        "",
        "",
        f"{sum(p_values)/len(p_values):.1f}",
        f"{sum(r_values)/len(r_values):.1f}",
        f"{sum(f_values)/len(f_values):.1f}",
    )

    console.print(table)


@click.command()
@click.argument("input_file")
def main(input_file):
    """Analyze annotation results and display performance metrics"""
    with open(input_file) as f:
        annotations = json.load(f)

    stats = aggregate_results(annotations)
    display_results(stats)
    macro_f1 = calculate_macro_f1(stats)
    print(f"Macro-F1: {macro_f1:.1f}%")


if __name__ == "__main__":
    main()

import jsPDF from 'jspdf';
import { Photo, Project } from './projects-api';
import { format } from 'date-fns';

export interface ReportOptions {
  title?: string;
  companyName?: string;
  companyLogo?: string; // Base64 image
  includeNotes?: boolean;
  includeLocation?: boolean;
  includeDate?: boolean;
  photosPerPage?: number;
}

export async function generateProjectReport(
  project: Project,
  photos: Photo[],
  options: ReportOptions = {}
): Promise<Blob> {
  const {
    title = `${project.name} - Photo Report`,
    companyName = 'FieldVision',
    companyLogo,
    includeNotes = true,
    includeLocation = true,
    includeDate = true,
    photosPerPage = 2,
  } = options;

  const pdf = new jsPDF('p', 'mm', 'a4');
  const pageWidth = pdf.internal.pageSize.getWidth();
  const pageHeight = pdf.internal.pageSize.getHeight();
  const margin = 15;
  const contentWidth = pageWidth - margin * 2;

  // Colors
  const primaryColor: [number, number, number] = [0, 78, 137]; // FieldVision blue
  const accentColor: [number, number, number] = [255, 107, 53]; // FieldVision orange

  // Helper to load image as base64
  async function loadImageAsBase64(url: string): Promise<string | null> {
    try {
      const response = await fetch(url);
      const blob = await response.blob();
      return new Promise((resolve) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result as string);
        reader.onerror = () => resolve(null);
        reader.readAsDataURL(blob);
      });
    } catch {
      return null;
    }
  }

  // Cover page
  function addCoverPage() {
    // Header bar
    pdf.setFillColor(...accentColor);
    pdf.rect(0, 0, pageWidth, 40, 'F');

    // Company name or logo
    pdf.setTextColor(255, 255, 255);
    pdf.setFontSize(24);
    pdf.setFont('helvetica', 'bold');
    pdf.text(companyName, margin, 27);

    // Report title
    pdf.setTextColor(...primaryColor);
    pdf.setFontSize(28);
    pdf.setFont('helvetica', 'bold');
    pdf.text(title, margin, 70);

    // Project details
    pdf.setFontSize(14);
    pdf.setFont('helvetica', 'normal');
    pdf.setTextColor(100, 100, 100);

    let y = 90;

    pdf.text(`Address: ${project.address}`, margin, y);
    y += 10;

    pdf.text(`Total Photos: ${photos.length}`, margin, y);
    y += 10;

    pdf.text(`Report Generated: ${format(new Date(), 'MMMM d, yyyy')}`, margin, y);
    y += 10;

    // Footer
    pdf.setFontSize(10);
    pdf.setTextColor(150, 150, 150);
    pdf.text('Generated with FieldVision', margin, pageHeight - 15);
  }

  // Photo pages
  async function addPhotoPages() {
    const photoHeight = photosPerPage === 1 ? 160 : 100;
    const photoWidth = contentWidth;

    for (let i = 0; i < photos.length; i++) {
      const photo = photos[i];
      const isFirstOnPage = i % photosPerPage === 0;

      if (isFirstOnPage) {
        pdf.addPage();

        // Page header
        pdf.setFillColor(...primaryColor);
        pdf.rect(0, 0, pageWidth, 20, 'F');
        pdf.setTextColor(255, 255, 255);
        pdf.setFontSize(12);
        pdf.setFont('helvetica', 'bold');
        pdf.text(project.name, margin, 13);
        pdf.setFont('helvetica', 'normal');
        pdf.text(`Page ${Math.floor(i / photosPerPage) + 2}`, pageWidth - margin - 20, 13);
      }

      const photoIndex = i % photosPerPage;
      const yOffset = 30 + photoIndex * (photoHeight + 30);

      // Load and add photo
      const imageData = await loadImageAsBase64(photo.remoteUrl);
      if (imageData) {
        try {
          // Calculate aspect ratio to fit
          const img = new Image();
          img.src = imageData;
          await new Promise((resolve) => {
            img.onload = resolve;
            img.onerror = resolve;
          });

          const imgAspect = img.width / img.height;
          let finalWidth = photoWidth;
          let finalHeight = photoWidth / imgAspect;

          if (finalHeight > photoHeight) {
            finalHeight = photoHeight;
            finalWidth = photoHeight * imgAspect;
          }

          const xOffset = margin + (photoWidth - finalWidth) / 2;

          pdf.addImage(imageData, 'JPEG', xOffset, yOffset, finalWidth, finalHeight);
        } catch (e) {
          // If image fails, add placeholder
          pdf.setFillColor(240, 240, 240);
          pdf.rect(margin, yOffset, photoWidth, photoHeight, 'F');
          pdf.setTextColor(150, 150, 150);
          pdf.setFontSize(12);
          pdf.text('Image could not be loaded', margin + photoWidth / 2 - 30, yOffset + photoHeight / 2);
        }
      }

      // Photo info
      const infoY = yOffset + photoHeight + 5;
      pdf.setFontSize(10);
      pdf.setTextColor(80, 80, 80);

      let infoText = `Photo ${i + 1}`;

      if (includeDate) {
        infoText += ` | ${format(new Date(photo.capturedAt), 'MMM d, yyyy h:mm a')}`;
      }

      if (includeLocation && photo.latitude && photo.longitude) {
        infoText += ` | ${photo.latitude.toFixed(4)}, ${photo.longitude.toFixed(4)}`;
      }

      pdf.text(infoText, margin, infoY);

      if (includeNotes && photo.note) {
        pdf.setFontSize(9);
        pdf.setTextColor(100, 100, 100);
        const noteLines = pdf.splitTextToSize(`Note: ${photo.note}`, contentWidth);
        pdf.text(noteLines.slice(0, 2), margin, infoY + 5);
      }
    }
  }

  // Generate the PDF
  addCoverPage();
  await addPhotoPages();

  return pdf.output('blob');
}

export function downloadReport(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
